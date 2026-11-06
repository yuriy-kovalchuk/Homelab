"""Qwen3.6-35B-A3B's MTP draft block, cut out of Unsloth's GGUF with HTTP range requests.

strata-cuda serves the GSQ-hybrid file, which has no draft block. strata-poly takes the block from
another file of the same model (--draft-model): blk.<n>.* with blk.<n>.nextn.eh_proj.weight, plus
general.architecture; everything else comes from the main file. The block is ~310 MiB of a 12.6 GB
file, so only the GGUF's tensor directory and the block's own bytes are read.

    python3 cut_draft.py OUT.gguf

Idempotent: an OUT whose SHA-256 matches is kept. The result is checked against SHA256 below (the
pinned revision's), so a mirror or proxy that changed the bytes fails the Job instead of feeding the
engine a broken block. Standard library only.
"""
import hashlib
import os
import struct
import sys
import urllib.request

REVISION = "5bc3e238d916f48a861bac2f8a1990a0e9b7e98d"   # unsloth/Qwen3.6-35B-A3B-MTP-GGUF, as UnbiasedStrata tested
URL = ("https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/resolve/%s/Qwen3.6-35B-A3B-UD-Q2_K_XL.gguf"
       % REVISION)
SHA256 = os.environ.get("DRAFT_SHA256", "")   # of the file this writes; empty = print it, don't check
ALIGN = 32
NUMBER = {0: "B", 1: "b", 2: "H", 3: "h", 4: "I", 5: "i", 6: "f", 7: "?", 10: "Q", 11: "q", 12: "d"}
UA = {"User-Agent": "homelab-strata-cuda-draft-cut"}


def get(start, end):
    req = urllib.request.Request(URL, headers=dict(UA, Range="bytes=%d-%d" % (start, end)))
    with urllib.request.urlopen(req, timeout=300) as r:
        # a server that ignores Range answers 200 with the file's start
        if r.status != 206 or not r.headers.get("Content-Range", "").startswith("bytes %d-%d/" % (start, end)):
            sys.exit("no range answer for bytes %d-%d (status %s)" % (start, end, r.status))
        data = r.read()
    if len(data) != end - start + 1:
        sys.exit("short read at %d: %d of %d bytes" % (start, len(data), end - start + 1))
    return data


def total_size():
    req = urllib.request.Request(URL, method="HEAD", headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return int(r.headers["Content-Length"])


class Reader:
    def __init__(self, data):
        self.d, self.at = data, 0

    def take(self, n):
        if self.at + n > len(self.d):
            raise EOFError
        b = self.d[self.at:self.at + n]
        self.at += n
        return b

    def num(self, fmt):
        return struct.unpack("<" + fmt, self.take(struct.calcsize("<" + fmt)))[0]

    def text(self):
        return self.take(self.num("Q")).decode("utf-8")

    def value(self, kind):
        if kind == 8:
            return self.text()
        if kind == 9:
            inner, n = self.num("I"), self.num("Q")
            return [self.value(inner) for _ in range(n)]
        return self.num(NUMBER[kind])


def directory(data):
    """[(name, dims, type, offset)], where tensor data starts, metadata."""
    r = Reader(data)
    if r.take(4) != b"GGUF" or r.num("I") != 3:
        sys.exit("not a GGUF v3 file")
    n_tensors, n_kv = r.num("Q"), r.num("Q")
    meta = {}
    for _ in range(n_kv):
        key = r.text()
        meta[key] = r.value(r.num("I"))
    tensors = []
    for _ in range(n_tensors):
        name = r.text()
        dims = [r.num("Q") for _ in range(r.num("I"))]
        kind, offset = r.num("I"), r.num("Q")
        tensors.append((name, dims, kind, offset))
    align = int(meta.get("general.alignment", ALIGN))
    return tensors, (r.at + align - 1) // align * align, meta


def text(s):
    b = s.encode("utf-8")
    return struct.pack("<Q", len(b)) + b


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 24), b""):
            h.update(chunk)
    return h.hexdigest()


def main(out):
    if os.path.exists(out) and SHA256 and sha256_of(out) == SHA256:
        print("%s is there and matches, nothing to do" % out)
        return
    size = total_size()
    n = 1 << 24
    while True:
        try:
            tensors, data_start, meta = directory(get(0, min(n, size) - 1))
            break
        except EOFError:
            if n >= size:
                sys.exit("the file ends inside its tensor directory")
            n *= 4
    arch = meta.get("general.architecture")
    if arch != "qwen35moe":
        sys.exit("unexpected architecture %r" % arch)
    blocks = {name.split(".")[1] for name, _, _, _ in tensors if name.startswith("blk.") and ".nextn." in name}
    if len(blocks) != 1:
        sys.exit("expected one draft block, found %s" % sorted(blocks))
    index = int(blocks.pop())
    if meta.get(arch + ".block_count") != index + 1 or meta.get(arch + ".nextn_predict_layers") != 1:
        sys.exit("the draft block is not the last of block_count")
    ends = sorted(o for _, _, _, o in tensors) + [size - data_start]
    prefix = "blk.%d." % index
    block = [(name, dims, kind, data_start + o, ends[ends.index(o) + 1] - o)
             for name, dims, kind, o in tensors if name.startswith(prefix)]

    kv = [("general.architecture", arch), ("general.name", "Qwen3.6-35B-A3B MTP draft block"),
          ("general.source", "unsloth/Qwen3.6-35B-A3B-MTP-GGUF@%s UD-Q2_K_XL" % REVISION)]
    head = b"GGUF" + struct.pack("<IQQ", 3, len(block), len(kv))
    for key, v in kv:
        head += text(key) + struct.pack("<I", 8) + text(v)
    at, starts = 0, []
    for name, dims, kind, _, nbytes in block:
        head += text(name) + struct.pack("<I", len(dims)) + struct.pack("<%dQ" % len(dims), *dims)
        head += struct.pack("<IQ", kind, at)
        starts.append(at)
        at += (nbytes + ALIGN - 1) // ALIGN * ALIGN
    head += b"\0" * (-len(head) % ALIGN)

    part = out + ".part"
    with open(part, "wb") as f:
        f.write(head)
        for (name, _, _, src, nbytes), dst in zip(block, starts):
            for off in range(0, nbytes, 32 << 20):
                m = min(32 << 20, nbytes - off)
                f.seek(len(head) + dst + off)
                f.write(get(src + off, src + off + m - 1))
            print("  %-42s %8.1f MiB" % (name, nbytes / 2**20), flush=True)
        f.truncate(len(head) + at)
    got = sha256_of(part)
    if SHA256 and got != SHA256:
        os.remove(part)
        sys.exit("SHA-256 %s, expected %s: the source changed or a proxy rewrote it" % (got, SHA256))
    os.replace(part, out)
    print("draft block: %s, %.1f MiB, sha256 %s" % (out, (len(head) + at) / 2**20, got))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: cut_draft.py OUT.gguf")
    main(sys.argv[1])
