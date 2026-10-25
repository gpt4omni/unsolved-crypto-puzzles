#!/usr/bin/env python3
"""
oracle.py -- reference model for the bountiful Fe compiler bug bounty.

Purpose:
    Replay a sequence of moveField(index) calls against a reference implementation of the
    published 15-puzzle rules. This is useful for parity checks and differential testing, but
    it is not a solution oracle: an actual bounty candidate must exploit behaviour that differs
    from these rules and must be tested against the compiled challenge contract.

Usage (run from the puzzle folder):
    python3 tools/oracle.py --selftest
    python3 tools/oracle.py --moves 11,7,6,5
    python3 tools/oracle.py --board 1,2,3,4,5,6,7,8,9,10,11,12,13,15,14,0 --moves 11,7
    python3 tools/oracle.py --parity
    python3 tools/oracle.py --live https://your-rpc.example

Output:
    MATCH reference rules after <n> moves  the sequence reaches the solved board
    NO MATCH <reason>                    it does not
    Move replay exits 0 on MATCH and 1 on NO MATCH. Successful --selftest, --parity and
    --live checks exit 0; argument, input and RPC errors are non-zero.

This tool never signs, sends or broadcasts anything. --live only reads.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
DATA = os.path.join(FOLDER, "data")

SOLVED_BOARD = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0]
IS_SOLVED_SELECTOR = "0x64d98f6e"

# shared/game_util.fe, ADJACENCY: for an empty field at index i, the fields that may move
# into it. This is the plain 4 by 4 grid adjacency.
ADJACENCY_DEPLOYED = {
    0: [1, 4],
    1: [0, 2, 5],
    2: [1, 3, 6],
    3: [2, 7],
    4: [0, 5, 8],
    5: [1, 4, 6, 9],
    6: [2, 5, 7, 10],
    7: [3, 6, 11],
    8: [4, 9, 12],
    9: [5, 8, 10, 13],
    10: [6, 9, 11, 14],
    11: [7, 10, 15],
    12: [8, 13],
    13: [9, 12, 14],
    14: [10, 13, 15],
    15: [11, 14],
}


def load_json(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


def validate_board(board):
    if len(board) != 16:
        raise ValueError("a board needs 16 values")
    if sorted(board) != list(range(16)):
        raise ValueError("a board must contain every value from 0 through 15 exactly once")
    return board


def start_board():
    return validate_board(list(load_json("challenges.json")["start_board"]))


def parse_board(text):
    text = text.strip()
    if text.lower().startswith("0x"):
        packed = int(text, 16)
        if packed >= 1 << 64:
            raise ValueError("a packed board must fit in 64 bits")
        board = [(packed >> (4 * i)) & 0xF for i in range(16)]
    else:
        board = [int(x.strip()) for x in text.split(",")]
    return validate_board(board)


def empty_index(board):
    return board.index(0)


def apply_move(board, index, table):
    """One moveField(index) call. Returns the new board, or raises ValueError like the
    contract's NotMovable / InvalidIndex reverts."""
    if index < 0 or index > 15:
        raise ValueError("InvalidIndex: %d" % index)
    e = empty_index(board)
    if index not in table[e]:
        raise ValueError("NotMovable: field %d is not listed for an empty field at %d" % (index, e))
    out = list(board)
    out[e] = out[index]
    out[index] = 0
    return out


def is_solved(board):
    return board == SOLVED_BOARD


def inversion_parity(board):
    """Parity of the number of inversions among the tiles, ignoring the empty field."""
    tiles = [v for v in board if v != 0]
    inversions = 0
    for i in range(len(tiles)):
        for j in range(i + 1, len(tiles)):
            if tiles[i] > tiles[j]:
                inversions += 1
    return inversions % 2


def solvability_invariant(board):
    """For a 4 by 4 board the quantity (inversions + row of the empty field) is unchanged by
    every legal move, so two boards with different values cannot be reached from each other.
    Returns that value modulo 2."""
    return (inversion_parity(board) + (empty_index(board) // 4)) % 2


def replay(board, moves, table):
    for index in moves:
        board = apply_move(board, index, table)
    return board


def read_live_states(rpc_url):
    """Read the board and isSolved() result of every deployed challenge. Read only."""
    import urllib.request

    def call(to, data):
        payload = json.dumps({
            "jsonrpc": "2.0", "id": 1, "method": "eth_call",
            "params": [{"to": to, "data": data}, "latest"],
        }).encode()
        req = urllib.request.Request(
            rpc_url, data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "unsolved-crypto-puzzles-oracle"},
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.loads(resp.read().decode())
        if "error" in body:
            raise RuntimeError(body["error"])
        return int(body["result"], 16)

    out = {}
    for entry in load_json("challenges.json")["challenges"]:
        getter = entry["get_board"]
        selector = getter["selector"]
        board = []
        for i in range(16):
            if getter["args"] == "row, col":
                args = "%064x%064x" % (i // 4, i % 4)
            else:
                args = "%064x" % i
            board.append(call(entry["address"], selector + args))
        try:
            validate_board(board)
        except ValueError as exc:
            raise RuntimeError(
                "%s returned an invalid board %s: %s" % (entry["name"], board, exc)
            ) from exc
        solved_raw = call(entry["address"], IS_SOLVED_SELECTOR)
        if solved_raw not in (0, 1):
            raise RuntimeError("isSolved() returned a non-boolean value for %s" % entry["name"])
        out[entry["name"]] = {"board": board, "is_solved": bool(solved_raw)}
    return out


def selftest():
    def require(condition, message):
        if not condition:
            raise AssertionError(message)

    start = start_board()
    goal = list(SOLVED_BOARD)

    require(is_solved(goal), "the solved board must be recognised as solved")
    require(not is_solved(start), "the deployed start board must not be recognised as solved")

    # The published rules cannot connect the two boards: the invariant differs.
    require(
        solvability_invariant(start) != solvability_invariant(goal),
        "the deployed start board must sit in the other half of the state space",
    )

    # Positive witness: move one tile out of the solved board, then replay the reverse move
    # through the same code used for user-supplied sequences.
    one_move_away = apply_move(goal, 14, ADJACENCY_DEPLOYED)
    require(not is_solved(one_move_away), "the witness board must not already be solved")
    require(
        solvability_invariant(one_move_away) == solvability_invariant(goal),
        "the invariant must keep a known legal one-move pair in the same component",
    )
    require(
        is_solved(replay(one_move_away, [15], ADJACENCY_DEPLOYED)),
        "the reference replay must find the known one-move solution",
    )

    # Negative control: a non-adjacent move must be rejected.
    rejected = False
    try:
        replay(goal, [0], ADJACENCY_DEPLOYED)
    except ValueError:
        rejected = True
    require(rejected, "the reference rules must reject a non-adjacent move")

    print("SELFTEST OK")
    return 0


def main():
    parser = argparse.ArgumentParser(description="reference model for the bountiful bug bounty")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--selftest", action="store_true", help="run the self-test and exit")
    mode.add_argument("--moves", default=None, help="comma separated moveField indices")
    mode.add_argument("--parity", action="store_true", help="print the solvability invariant and exit")
    mode.add_argument(
        "--live", default=None, metavar="RPC_URL",
        help="read live boards and isSolved() results, then exit",
    )
    parser.add_argument(
        "--board", default=None,
        help="16 comma separated values, or a packed hex board; only for --moves or --parity",
    )
    args = parser.parse_args()

    if args.board is not None and (args.selftest or args.live):
        parser.error("--board may only be used with --moves or --parity")

    if args.selftest:
        return selftest()

    try:
        board = parse_board(args.board) if args.board else start_board()
    except ValueError as exc:
        parser.error(str(exc))

    if args.live:
        try:
            live_states = read_live_states(args.live)
        except (KeyError, OSError, RuntimeError, ValueError) as exc:
            parser.error("--live failed: %s" % exc)
        for name, live in sorted(live_states.items()):
            board = live["board"]
            print("%-13s %s  invariant=%d  isSolved()=%s" % (
                name, board, solvability_invariant(board), str(live["is_solved"]).lower(),
            ))
        return 0

    if args.parity:
        print("board      %s" % board)
        print("invariant  %d" % solvability_invariant(board))
        print("solved     %d" % solvability_invariant(SOLVED_BOARD))
        print("reachable  %s" % ("yes" if solvability_invariant(board) == solvability_invariant(SOLVED_BOARD) else "no"))
        return 0

    try:
        moves = [int(x) for x in args.moves.split(",") if x.strip() != ""]
    except ValueError:
        parser.error("--moves must be a comma separated list of integers")
    try:
        final = replay(board, moves, ADJACENCY_DEPLOYED)
    except ValueError as exc:
        print("NO MATCH %s" % exc)
        return 1

    if is_solved(final):
        print("MATCH reference rules after %d moves" % len(moves))
        return 0
    print("NO MATCH board is %s after %d moves" % (final, len(moves)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
