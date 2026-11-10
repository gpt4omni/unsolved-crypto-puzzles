#!/usr/bin/env python3
"""
boha_sync.py -- import the unsolved records from the boha dataset.

Purpose:
    Read a boha export (the npm package is @agntn/puzzles), keep the records whose
    status is unsolved, and write a small watchlist under boha/. The watchlist is not
    a curated puzzle folder: it is the machine-readable list the scheduled workflow
    diffs against, so a new unsolved record becomes a pull request.

Usage (run from the repository root):
    python3 tools/boha_sync.py --export /tmp/boha-export.json
    python3 tools/boha_sync.py --export /tmp/boha-export.json --recheck-all
    python3 tools/boha_sync.py --export /tmp/boha-export.json --check

Input:
    --export PATH       boha export JSON. If omitted, the tool runs
                        "npx --yes @agntn/puzzles export" and reads stdout.
    --check             report whether the watchlist would change; write nothing.
    --no-address-check  skip live balance checks.
    --recheck-all       check every unsolved address, not only new records.

Output:
    boha/unsolved.json  the 113 unsolved records, normalized.
    boha/README.md      a readable table generated from the same records.
    boha/export.json.gz the complete boha export, compressed, for provenance.

Address checks:
    Bitcoin and Litecoin use one batched Electrum request per server. A record whose
    Electrum lookup fails falls back to the mempool.space or litecoinspace.org address
    endpoint. Ethereum uses a public JSON-RPC endpoint; Arweave uses the wallet balance
    endpoint. A live check is evidence, not a promise: boha can lag the chain.
"""

import argparse
import gzip
import hashlib
import json
import os
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import date

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOHA_DIR = os.path.join(REPO_ROOT, "boha")
UNSOLVED_PATH = os.path.join(BOHA_DIR, "unsolved.json")
README_PATH = os.path.join(BOHA_DIR, "README.md")
EXPORT_GZ_PATH = os.path.join(BOHA_DIR, "export.json.gz")

TODAY = date.today().isoformat()

BTC_SERVERS = [
    ("electrum.blockstream.info", 50001, False),
    ("electrum.blockstream.info", 50002, True),
]
LTC_SERVERS = [
    ("electrum-ltc.bysh.me", 50001, False),
]
ETH_RPCS = [
    "https://ethereum-rpc.publicnode.com",
    "https://1rpc.io/eth",
    "https://rpc.flashbots.net",
    "https://cloudflare-eth.com",
    "https://eth.drpc.org",
]
BLOCKSCOUT_V2 = "https://eth.blockscout.com/api/v2/addresses/{address}"
BLOCKSCOUT_V1 = "https://eth.blockscout.com/api?module=account&action=balance&address={address}&tag=latest"
BATCH_SIZE = 40
NETWORK_TIMEOUT = 20
HTTP_HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
}


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def write_gz(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(gzip.compress(data, compresslevel=9, mtime=0))


def load_export(path):
    if path:
        return read_json(path)
    result = subprocess.run(
        ["npx", "--yes", "@agntn/puzzles", "export"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def flatten(doc):
    records = []
    for collection in doc.get("collections", []):
        author = collection.get("author") or {}
        author_name = author.get("name") if isinstance(author, dict) else str(author)
        for puzzle in collection.get("puzzles", []):
            record = dict(puzzle)
            record["_collection"] = collection.get("name", "")
            record["_author"] = author_name or ""
            records.append(record)
    return records


def address_parts(record):
    address = record.get("address")
    if isinstance(address, dict):
        return address.get("value") or "", address.get("kind") or ""
    return address or "", ""


def prize_asset(chain):
    return {
        "bitcoin": "BTC",
        "ethereum": "ETH",
        "arweave": "AR",
        "litecoin": "LTC",
    }.get(chain, "")


def normalize(record):
    address, kind = address_parts(record)
    start = record.get("start_date") or ""
    return {
        "id": record.get("id", ""),
        "collection": record.get("_collection", ""),
        "author": record.get("_author", ""),
        "chain": record.get("chain", ""),
        "address": address,
        "address_kind": kind,
        "status": record.get("status", ""),
        "prize": record.get("prize"),
        "prize_asset": prize_asset(record.get("chain", "")),
        "start_date": start[:10] if start else None,
        "source_url": record.get("source_url"),
        "techniques": record.get("techniques"),
        "pubkey": record.get("pubkey"),
        "pre_genesis": bool(record.get("pre_genesis")),
        "hints": record.get("hints") or [],
        "assets": record.get("assets") or {},
        "stages": record.get("stages") or [],
        "hint_count": len(record.get("hints") or []),
        "tx_count": len(record.get("transactions") or []),
    }


# ---------------------------------------------------------------------------
# Address decoding
# ---------------------------------------------------------------------------

B58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def b58decode(value):
    number = 0
    for char in value:
        number = number * 58 + B58_ALPHABET.index(char)
    body = number.to_bytes((number.bit_length() + 7) // 8, "big")
    return b"\x00" * (len(value) - len(value.lstrip("1"))) + body


def b58check(value):
    raw = b58decode(value)
    payload, checksum = raw[:-4], raw[-4:]
    expected = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
    if checksum != expected:
        raise ValueError("base58 checksum mismatch")
    return payload


def bech32_polymod(values):
    generators = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    checksum = 1
    for value in values:
        top = checksum >> 25
        checksum = ((checksum & 0x1FFFFFF) << 5) ^ value
        for index in range(5):
            if (top >> index) & 1:
                checksum ^= generators[index]
    return checksum


def bech32_hrp_expand(hrp):
    return [ord(char) >> 5 for char in hrp] + [0] + [ord(char) & 31 for char in hrp]


def bech32_decode(value):
    position = value.rfind("1")
    if position < 1:
        raise ValueError("bech32 separator missing")
    hrp, data = value[:position], value[position + 1:]
    values = [BECH32_CHARSET.index(char) for char in data]
    if bech32_polymod(bech32_hrp_expand(hrp) + values) != 1:
        raise ValueError("bech32 checksum mismatch")
    return hrp, values[:-6]


def convert_bits(data, from_bits, to_bits, pad=True):
    accumulator = 0
    bits = 0
    result = []
    max_value = (1 << to_bits) - 1
    for value in data:
        accumulator = (accumulator << from_bits) | value
        bits += from_bits
        while bits >= to_bits:
            bits -= to_bits
            result.append((accumulator >> bits) & max_value)
    if pad and bits:
        result.append((accumulator << (to_bits - bits)) & max_value)
    return result


def script_pubkey(address, chain):
    lower = address.lower()
    if lower.startswith("bc1") or lower.startswith("ltc1"):
        _, data = bech32_decode(lower)
        version = data[0]
        program = bytes(convert_bits(data[1:], 5, 8, False))
        if version == 0 and len(program) == 20:
            return b"\x00\x14" + program
        if version == 0 and len(program) == 32:
            return b"\x00\x20" + program
        if version == 1 and len(program) == 32:
            return b"\x51\x20" + program
        raise ValueError("unsupported segwit version")

    payload = b58check(address)
    version = payload[0]
    hash160 = payload[1:]
    if chain == "litecoin":
        if version == 48:
            return b"\x76\xa9\x14" + hash160 + b"\x88\xac"
        if version == 50:
            return b"\xa9\x14" + hash160 + b"\x87"
    else:
        if version == 0:
            return b"\x76\xa9\x14" + hash160 + b"\x88\xac"
        if version == 5:
            return b"\xa9\x14" + hash160 + b"\x87"
    raise ValueError("unsupported base58 version")


def scripthash(address, chain):
    return hashlib.sha256(script_pubkey(address, chain)).digest()[::-1].hex()


# ---------------------------------------------------------------------------
# Live balance checks
# ---------------------------------------------------------------------------


def electrum_batch(chain, addresses):
    servers = LTC_SERVERS if chain == "litecoin" else BTC_SERVERS
    pending = list(addresses)
    results = {}
    for host, port, use_ssl in servers:
        if not pending:
            break
        try:
            with socket.create_connection((host, port), timeout=NETWORK_TIMEOUT) as raw:
                sock = raw
                if use_ssl:
                    sock = ssl.create_default_context().wrap_socket(raw, server_hostname=host)
                for start in range(0, len(pending), BATCH_SIZE):
                    chunk = pending[start:start + BATCH_SIZE]
                    requests = []
                    lookup = {}
                    for index, address in enumerate(chunk):
                        try:
                            digest = scripthash(address, chain)
                        except Exception:
                            continue
                        lookup[index] = (address, digest)
                        requests.append({
                            "jsonrpc": "2.0",
                            "id": index,
                            "method": "blockchain.scripthash.get_balance",
                            "params": [digest],
                        })
                    if not requests:
                        continue
                    sock.sendall((json.dumps(requests) + "\n").encode())
                    payload = b""
                    while True:
                        try:
                            parsed = json.loads(payload.decode())
                            break
                        except (UnicodeDecodeError, json.JSONDecodeError):
                            chunk_bytes = sock.recv(65536)
                            if not chunk_bytes:
                                raise ConnectionError("electrum closed the connection")
                            payload += chunk_bytes
                    if isinstance(parsed, dict):
                        parsed = [parsed]
                    for item in parsed:
                        index = item.get("id")
                        if index not in lookup:
                            continue
                        address = lookup[index][0]
                        result = item.get("result") or {}
                        if "error" in item:
                            continue
                        confirmed = int(result.get("confirmed", 0))
                        unconfirmed = int(result.get("unconfirmed", 0))
                        results[address] = confirmed
                    for address, _digest in lookup.values():
                        if address in results:
                            pending.remove(address)
        except Exception:
            continue
    return results


def explorer_balance(chain, address):
    host = "litecoinspace.org" if chain == "litecoin" else "mempool.space"
    url = f"https://{host}/api/address/{address}"
    with urllib.request.urlopen(url, timeout=NETWORK_TIMEOUT) as response:
        data = json.loads(response.read().decode())
    stats = data.get("chain_stats", {})
    funded = int(stats.get("funded_txo_sum", 0))
    spent = int(stats.get("spent_txo_sum", 0))
    return funded, spent


def balance_state(chain, funded, spent):
    balance = funded - spent
    if balance > 0:
        return "funded-unspent", balance
    if funded == 0:
        return "unfunded", 0
    if spent >= funded:
        return "swept", 0
    return "partially-spent", balance


def check_utxo_chain(chain, addresses):
    electrum = electrum_batch(chain, addresses)
    results = {}
    for address in addresses:
        if electrum.get(address, 0) > 0:
            results[address] = {
                "state": "funded-unspent",
                "balance": electrum[address],
                "unit": "sats" if chain == "bitcoin" else "litoshis",
                "source": "electrum",
            }
            continue
        # A zero balance from Electrum cannot tell an unfunded address from a swept
        # one. The explorer endpoint reports both funded and spent totals, so it is
        # the tie-breaker for zero-balance addresses.
        try:
            funded, spent = explorer_balance(chain, address)
            state, balance = balance_state(chain, funded, spent)
            results[address] = {
                "state": state,
                "balance": balance,
                "unit": "sats" if chain == "bitcoin" else "litoshis",
                "source": "explorer",
            }
        except Exception as exc:
            results[address] = {
                "state": "ERROR",
                "balance": None,
                "unit": "sats" if chain == "bitcoin" else "litoshis",
                "source": f"error: {exc}",
            }
    return results


def eth_rpc(url, method, params):
    body = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params,
    }).encode()
    request = urllib.request.Request(
        url,
        data=body,
        headers=HTTP_HEADERS,
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as response:
        data = json.loads(response.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]


def blockscout_balance(address):
    request = urllib.request.Request(
        BLOCKSCOUT_V2.format(address=address),
        headers=HTTP_HEADERS,
    )
    with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as response:
        data = json.loads(response.read().decode())
    if "coin_balance" in data and data.get("coin_balance") is not None:
        balance = int(data["coin_balance"])
        return balance, bool(data.get("is_contract"))
    request = urllib.request.Request(
        BLOCKSCOUT_V1.format(address=address),
        headers=HTTP_HEADERS,
    )
    with urllib.request.urlopen(request, timeout=NETWORK_TIMEOUT) as response:
        data = json.loads(response.read().decode())
    if data.get("status") != "1":
        raise RuntimeError(data.get("message", "blockscout returned no balance"))
    return int(data["result"]), False


def check_ethereum(address):
    last_error = None
    for url in ETH_RPCS:
        try:
            balance = int(eth_rpc(url, "eth_getBalance", [address, "latest"]), 16)
            if balance > 0:
                return {
                    "state": "funded-unspent",
                    "balance": balance,
                    "unit": "wei",
                    "source": "rpc",
                }
            nonce = int(eth_rpc(url, "eth_getTransactionCount", [address, "latest"]), 16)
            code = eth_rpc(url, "eth_getCode", [address, "latest"])
            has_code = code not in ("0x", "0x0")
            if has_code:
                state = "zero-balance-contract"
            elif nonce == 0:
                state = "unfunded"
            else:
                state = "swept"
            return {
                "state": state,
                "balance": balance,
                "unit": "wei",
                "source": "rpc",
            }
        except Exception as exc:
            last_error = exc
    try:
        balance, has_code = blockscout_balance(address)
        if balance > 0:
            state = "funded-unspent"
        elif has_code:
            state = "zero-balance-contract"
        else:
            state = "unfunded"
        return {
            "state": state,
            "balance": balance,
            "unit": "wei",
            "source": "blockscout",
        }
    except Exception as exc:
        last_error = exc
    return {
        "state": "ERROR",
        "balance": None,
        "unit": "wei",
        "source": f"error: {last_error}",
    }


def check_arweave(address):
    url = f"https://arweave.net/wallet/{address}/balance"
    try:
        with urllib.request.urlopen(url, timeout=NETWORK_TIMEOUT) as response:
            winston = int(response.read().decode().strip())
        return {
            "state": "funded-unspent" if winston > 0 else "unfunded",
            "balance": winston,
            "unit": "winston",
            "source": "arweave",
        }
    except Exception as exc:
        return {
            "state": "ERROR",
            "balance": None,
            "unit": "winston",
            "source": f"error: {exc}",
        }


def check_addresses(records):
    grouped = {}
    for record in records:
        grouped.setdefault(record["chain"], []).append(record["address"])
    results = {}
    for chain, addresses in grouped.items():
        unique = sorted({address for address in addresses if address})
        if chain in ("bitcoin", "litecoin"):
            checked = check_utxo_chain(chain, unique)
        elif chain == "ethereum":
            checked = {address: check_ethereum(address) for address in unique}
        elif chain == "arweave":
            checked = {address: check_arweave(address) for address in unique}
        else:
            checked = {
                address: {
                    "state": "unknown",
                    "balance": None,
                    "unit": "",
                    "source": "no automatic checker",
                }
                for address in unique
            }
        for address, result in checked.items():
            results[(chain, address)] = result
    return results


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


def fmt_number(value):
    if value is None:
        return ""
    if isinstance(value, float):
        return f"{value:,.8f}".rstrip("0").rstrip(".")
    return str(value)


def fmt_balance(checked):
    if not checked or checked.get("balance") is None:
        return checked.get("state", "unknown") if checked else "not checked"
    balance = checked["balance"]
    unit = checked.get("unit", "")
    if unit == "wei":
        shown = f"{balance / 1e18:.6f} ETH"
    elif unit == "winston":
        shown = f"{balance / 1e12:.6f} AR"
    elif unit == "litoshis":
        shown = f"{balance / 1e8:.6f} LTC"
    else:
        shown = f"{balance:,} sats"
    return f"{checked.get('state', 'unknown')} ({shown})"


def build_unsolved_doc(doc, records):
    return {
        "schema_version": 1,
        "source": "https://github.com/agntn/puzzles",
        "package": "@agntn/puzzles",
        "boha_version": doc.get("version", ""),
        "boha_data_version": doc.get("data_version", ""),
        "generated_on": TODAY,
        "counts": {
            "all_records": sum(len(c.get("puzzles", [])) for c in doc.get("collections", [])),
            "collections": len(doc.get("collections", [])),
            "unsolved": len(records),
        },
        "puzzles": records,
    }


def collection_rows(records):
    counts = {}
    for record in records:
        key = record["collection"]
        counts.setdefault(key, {"total": 0, "funded": 0})
        counts[key]["total"] += 1
        if str(record.get("checked", {}).get("state", "")).startswith(("funded", "contract")):
            counts[key]["funded"] += 1
    return counts


def build_readme(doc, records, new_ids, removed_ids):
    total = sum(len(c.get("puzzles", [])) for c in doc.get("collections", []))
    counts = collection_rows(records)
    lines = [
        "# boha unsolved watchlist",
        "",
        "This folder mirrors the unsolved records from the boha dataset, published on npm",
        "as `@agntn/puzzles`. It is a watchlist, not a curated puzzle folder: the files are",
        "generated by `tools/boha_sync.py`, and the scheduled `boha sync` workflow opens a",
        "pull request when a new unsolved record appears.",
        "",
        "The full export is in [`export.json.gz`](export.json.gz). The readable record list is",
        "[`unsolved.json`](unsolved.json). A record here is not an endorsement and its live",
        "balance can change between syncs; verify the address before spending time on it.",
        "",
        "## Snapshot",
        "",
        f"- boha version: `{doc.get('version', '')}` (data `{doc.get('data_version', '')}`)",
        f"- all records: {total} across {len(doc.get('collections', []))} collections",
        f"- unsolved records: {len(records)}",
        f"- new in this sync: {len(new_ids)}",
        f"- no longer unsolved: {len(removed_ids)}",
        "",
    ]
    if new_ids:
        lines.append("New records: " + ", ".join(f"`{value}`" for value in new_ids))
        lines.append("")
    if removed_ids:
        lines.append("Removed records: " + ", ".join(f"`{value}`" for value in removed_ids))
        lines.append("")

    lines.extend([
        "## Unsolved records",
        "",
        "| ID | Collection | Chain | Prize | Address | Live check | Source |",
        "|---|---|---|---|---|---|---|",
    ])
    for record in sorted(records, key=lambda item: (item["collection"], item["id"])):
        source = record.get("source_url") or ""
        source_cell = f"[post]({source})" if source and "(" not in source and ")" not in source else source
        address = record.get("address", "")
        lines.append(
            "| `{id}` | {collection} | {chain} | {prize} | `{address}` | {check} | {source} |".format(
                id=record["id"],
                collection=record["collection"],
                chain=record["chain"],
                prize=fmt_number(record.get("prize")) + " " + record.get("prize_asset", ""),
                address=address,
                check=fmt_balance(record.get("checked")),
                source=source_cell,
            )
        )

    lines.extend([
        "",
        "## By collection",
        "",
        "| Collection | Unsolved records | Funded on last check |",
        "|---|---:|---:|",
    ])
    for key in sorted(counts):
        lines.append(f"| {key} | {counts[key]['total']} | {counts[key]['funded']} |")

    lines.extend([
        "",
        "## How this stays current",
        "",
        "The `boha sync` workflow runs once a day. It installs the latest",
        "`@agntn/puzzles`, exports the dataset, and runs:",
        "",
        "```sh",
        "python3 tools/boha_sync.py --export /tmp/boha-export.json",
        "```",
        "",
        "The tool keeps the full export, refreshes the unsolved list, and checks new",
        "addresses. Bitcoin and Litecoin go through one batched Electrum request; a failed",
        "lookup falls back to the explorer address endpoint. Ethereum uses a public RPC and",
        "Arweave uses its wallet endpoint. If nothing changed, the workflow writes nothing.",
        "",
        "To refresh every balance by hand:",
        "",
        "```sh",
        "python3 tools/boha_sync.py --export /tmp/boha-export.json --recheck-all",
        "```",
        "",
        "## Credit",
        "",
        "The data is from [agntn/puzzles](https://github.com/agntn/puzzles), the npm package",
        "`@agntn/puzzles` and the Rust crate `boha`. It is MIT licensed. This folder only",
        "stores the records and a generated view of them.",
        "",
    ])
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="Sync the unsolved records from boha.")
    parser.add_argument("--export", default=None, help="boha export JSON path")
    parser.add_argument("--check", action="store_true", help="report changes without writing")
    parser.add_argument("--no-address-check", action="store_true", help="skip live balance checks")
    parser.add_argument("--recheck-all", action="store_true", help="check every unsolved address")
    args = parser.parse_args()

    doc = load_export(args.export)
    all_records = flatten(doc)
    unsolved = [record for record in all_records if record.get("status") == "unsolved"]
    if not unsolved:
        print("boha export contains no unsolved records; nothing to do.")
        return 0

    previous_doc = read_json(UNSOLVED_PATH) if os.path.isfile(UNSOLVED_PATH) else {"puzzles": []}
    previous = {record["id"]: record for record in previous_doc.get("puzzles", [])}
    current_ids = {record.get("id", "") for record in unsolved}
    previous_ids = set(previous)
    new_ids = sorted(current_ids - previous_ids)
    removed_ids = sorted(previous_ids - current_ids)

    if args.check:
        if new_ids or removed_ids:
            print("STALE: the boha watchlist would change.")
            if new_ids:
                print("  new: " + ", ".join(new_ids))
            if removed_ids:
                print("  removed: " + ", ".join(removed_ids))
            return 1
        print("OK: the boha watchlist has no new or removed unsolved records.")
        return 0

    normalized = [normalize(record) for record in unsolved]
    by_id = {record["id"]: record for record in normalized}

    to_check = []
    for record in normalized:
        old = previous.get(record["id"])
        if args.recheck_all or old is None or old.get("address") != record.get("address"):
            to_check.append(record)
    if args.no_address_check:
        for record in to_check:
            record["checked"] = {
                "on": TODAY,
                "state": "unknown",
                "balance": None,
                "unit": "",
                "source": "skipped",
            }
    else:
        checked = check_addresses(to_check)
        for record in to_check:
            record["checked"] = dict(
                checked.get((record["chain"], record["address"]), {
                    "state": "unknown",
                    "balance": None,
                    "unit": "",
                    "source": "missing",
                }),
                on=TODAY,
            )

    for record in normalized:
        old = previous.get(record["id"])
        if old and "checked" in old and record["id"] not in {item["id"] for item in to_check}:
            record["checked"] = old["checked"]

    new_doc = build_unsolved_doc(doc, normalized)
    new_json = json.dumps(new_doc, indent=2, ensure_ascii=True) + "\n"
    old_json = ""
    if os.path.isfile(UNSOLVED_PATH):
        with open(UNSOLVED_PATH, encoding="utf-8") as f:
            old_json = f.read()

    export_bytes = json.dumps(doc, ensure_ascii=True, separators=(",", ":")).encode()
    old_export = b""
    if os.path.isfile(EXPORT_GZ_PATH):
        with open(EXPORT_GZ_PATH, "rb") as f:
            old_export = f.read()
    new_export = gzip.compress(export_bytes, compresslevel=9, mtime=0)

    readme = build_readme(doc, normalized, new_ids, removed_ids)
    old_readme = ""
    if os.path.isfile(README_PATH):
        with open(README_PATH, encoding="utf-8") as f:
            old_readme = f.read()

    changed = (new_json != old_json) or (readme != old_readme)
    if not changed:
        print(f"No watchlist change ({len(normalized)} unsolved records).")
        return 0

    write_text(UNSOLVED_PATH, new_json)
    write_text(README_PATH, readme)
    write_gz(EXPORT_GZ_PATH, new_export)

    print(f"Wrote {len(normalized)} unsolved records.")
    if new_ids:
        print("New: " + ", ".join(new_ids))
    if removed_ids:
        print("Removed: " + ", ".join(removed_ids))
    return 0


if __name__ == "__main__":
    sys.exit(main())
