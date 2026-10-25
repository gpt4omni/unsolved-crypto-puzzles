# Author and community material, dated

Verbatim excerpts from the contest's own code and its surrounding public material, with
dates and links. RushWallet was a KryptoKit product; the contest ran on rushwallet.com,
now defunct.

## The derivation, from the contest's own script

Archived capture, 2015-02-08: [rushwallet.com/js/contest.js](http://web.archive.org/web/20150208174448/https://rushwallet.com/js/contest.js).

```javascript
var bytes = Bitcoin.Crypto.SHA256($("#txtBrain").val(), {asBytes: true});
var btcKey = new Bitcoin.Key(bytes);
var address = btcKey.getBitcoinAddress().toString();
```

The same file lists the contest's 30 addresses in a JavaScript array, `13Q8hJqagtd77ojTJcEZPjTz2sBFSsYxyj`
(puzzle #30) last among them.

## The promotional video's audio track

A Morse-code tone recovered from the contest's promotional video (re-uploaded copy of
`sr8lBrtd9U4`, since removed from YouTube; a hosted copy of the audio survived at
`clyp.it/j5ivo3wg`) decodes to:

> "WHAT IF THE GAME STARTED WAY BEFORE ? MAKING PUZZLES IS MORE FUN THAN WALLETS. IT
> MIGHT BE OVER BUT THE PUZZLES ARE JUST THE BEGINNING. -3302"

## A PGP-signed message posted 2014-12-25

Signed by a poster using the handle `aa1GLbc4` on the contest's BitcoinTalk discussion
thread ([bitcointalk.org/index.php?topic=793720.0](https://bitcointalk.org/index.php?topic=793720.0)):

> "There is more than you can see here, There was more than you could hear before,
> There are more than you think there are, seek and you shall find. Merry Christmas..."

## A QR code visible in the video

Decoded from a video frame: "you thought this was a clue but its not that easy". This is
not a clue for #30: it is the passphrase for a different, already-claimed puzzle in the
same contest (#19).

## Community status, BitcoinTalk thread 793720

As of the most recent read of the thread, a moderator states no public guess has solved
puzzle #30; the other 29 contest brainwallets are confirmed claimed by their solvers over
the life of the thread.
