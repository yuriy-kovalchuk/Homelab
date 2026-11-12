"""The GSQ-hybrid Qwen3.6 GGUF with Unsloth's MTP draft block appended: one file that
llama.cpp (--spec-type draft-mtp, the head shares the model's embeddings and output)
and strata-poly (the block found in the model's own file) both read.

    python3 merge_mtp.py MODEL.gguf DRAFT.gguf OUT.gguf

MODEL: Qwen3.6-35B-A3B-GSQ-hybrid.gguf (40 blocks, no MTP).
DRAFT: Qwen3.6-35B-A3B-MTP-draft.gguf, blk.40.* cut out of Unsloth's UD-Q2_K_XL by
       strata-cuda's draft-block Job.

The output keeps MODEL's metadata bytes as they are except:
  qwen35moe.block_count                40 -> 41
  qwen35moe.attention.recurrent_layers 40 entries -> 41, the MTP block not recurrent
                                       (llama.cpp wants one per block; its fallback marks
                                       the MTP block the same way)
  qwen35moe.nextn_predict_layers       added, 1
MODEL's tensor data is copied unchanged at the same offsets, the block's tensors follow
it. Inputs are checked against MODEL_SHA256 / DRAFT_SHA256 when set; an OUT whose
OUT_SHA256 matches is kept. Standard library only, streams in 64 MiB pieces.
"""
import hashlib
import os
import struct
import sys

ARCH = "qwen35moe"
SIZES = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8}
PIECE = 64 << 20


class Reader:
    def __init__(self, f):
        self.f = f

    def num(self, fmt):
        n = struct.calcsize("<" + fmt)
        b = self.f.read(n)
        if len(b) != n:
            raise EOFError
        return struct.unpack("<" + fmt, b)[0]

    def text(self):
        return self.f.read(self.num("Q")).decode("utf-8")

    def skip_value(self, kind):
        if kind == 8:
            self.f.seek(self.num("Q"), 1)
        elif kind == 9:
            inner, n = self.num("I"), self.num("Q")
            if inner in SIZES:
                self.f.seek(SIZES[inner] * n, 1)
            else:
                for _ in range(n):
                    self.skip_value(inner)
        else:
            self.f.seek(SIZES[kind], 1)


def parse(path):
    """kvs [(key, kind, raw bytes of the whole entry)], tensors [(name, dims, type, offset)], alignment,
    data start, file size."""
    with open(path, "rb") as f:
        r = Reader(f)
        if f.read(4) != b"GGUF" or r.num("I") != 3:
            sys.exit("%s: not a GGUF v3 file" % path)
        n_tensors, n_kv = r.num("Q"), r.num("Q")
        kvs = []
        for _ in range(n_kv):
            start = f.tell()
            key = r.text()
            kind = r.num("I")
            r.skip_value(kind)
            end = f.tell()
            f.seek(start)
            kvs.append((key, kind, f.read(end - start)))
        tensors = []
        for _ in range(n_tensors):
            name = r.text()
            dims = [r.num("Q") for _ in range(r.num("I"))]
            tensors.append((name, dims, r.num("I"), r.num("Q")))
        align = 32
        for key, kind, raw in kvs:
            if key == "general.alignment":
                align = struct.unpack("<I", raw[-4:])[0]
        data_start = (f.tell() + align - 1) // align * align
        size = os.fstat(f.fileno()).st_size
    return kvs, tensors, align, data_start, size


def text(s):
    b = s.encode("utf-8")
    return struct.pack("<Q", len(b)) + b


def u32(key, v):
    return text(key) + struct.pack("<II", 4, v)


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(PIECE), b""):
            h.update(chunk)
    return h.hexdigest()


def check(path, env):
    want = os.environ.get(env, "")
    if want:
        got = sha256_of(path)
        if got != want:
            sys.exit("%s: SHA-256 %s, expected %s (%s)" % (path, got, want, env))
        print("%s: SHA-256 ok" % path, flush=True)


def copy(src, start, n, dst):
    with open(src, "rb") as f:
        f.seek(start)
        while n:
            b = f.read(min(PIECE, n))
            if not b:
                sys.exit("%s ended early" % src)
            dst.write(b)
            n -= len(b)


def main(model, draft, out):
    if os.path.exists(out) and os.environ.get("OUT_SHA256") and sha256_of(out) == os.environ["OUT_SHA256"]:
        print("%s is there and matches, nothing to do" % out)
        return
    check(model, "MODEL_SHA256")
    check(draft, "DRAFT_SHA256")
    kvs, tensors, align, data_start, size = parse(model)
    dkvs, dtensors, dalign, ddata_start, dsize = parse(draft)

    meta = {k: (kind, raw) for k, kind, raw in kvs}
    arch_raw = meta.get("general.architecture", (None, b""))[1]
    if not arch_raw.endswith(text(ARCH)):
        sys.exit("%s is not a %s model" % (model, ARCH))
    bc = ARCH + ".block_count"
    if bc not in meta or meta[bc][0] != 4:
        sys.exit("%s: no u32 %s" % (model, bc))
    n_layer = struct.unpack("<I", meta[bc][1][-4:])[0]
    if ARCH + ".nextn_predict_layers" in meta or any(n.startswith("blk.%d." % n_layer) for n, _, _, _ in tensors):
        sys.exit("%s already has a block %d" % (model, n_layer))
    prefix = "blk.%d." % n_layer
    if not dtensors or any(not n.startswith(prefix) for n, _, _, _ in dtensors) or \
            not any(n == prefix + "nextn.eh_proj.weight" for n, _, _, _ in dtensors):
        sys.exit("%s is not the draft block %d" % (draft, n_layer))

    rl = ARCH + ".attention.recurrent_layers"
    out_kv = []
    for key, kind, raw in kvs:
        if key == bc:
            out_kv.append(u32(key, n_layer + 1))
        elif key == rl:
            # array of bool: the 40 that are there, then the MTP block (attention, not recurrent)
            body = raw[len(text(key)) + 4:]
            inner, n = struct.unpack("<IQ", body[:12])
            if inner != 7 or n != n_layer:
                sys.exit("%s: %s is not %d bools" % (model, rl, n_layer))
            out_kv.append(text(key) + struct.pack("<IIQ", 9, 7, n + 1) + body[12:12 + n] + b"\x00")
        else:
            out_kv.append(raw)
    out_kv.append(u32(ARCH + ".nextn_predict_layers", 1))

    model_data = size - data_start
    base = (model_data + align - 1) // align * align
    head = b"GGUF" + struct.pack("<IQQ", 3, len(tensors) + len(dtensors), len(out_kv)) + b"".join(out_kv)
    for name, dims, kind, off in tensors:
        head += text(name) + struct.pack("<I", len(dims)) + struct.pack("<%dQ" % len(dims), *dims)
        head += struct.pack("<IQ", kind, off)
    for name, dims, kind, off in dtensors:
        if off % align:
            sys.exit("%s: %s is not aligned to %d" % (draft, name, align))
        head += text(name) + struct.pack("<I", len(dims)) + struct.pack("<%dQ" % len(dims), *dims)
        head += struct.pack("<IQ", kind, base + off)
    head += b"\0" * (-len(head) % align)

    part = out + ".part"
    with open(part, "wb") as f:
        f.write(head)
        copy(model, data_start, model_data, f)
        f.write(b"\0" * (base - model_data))
        copy(draft, ddata_start, dsize - ddata_start, f)
    # read back: the same tensors, the old ones at their old offsets
    kvs2, tensors2, _, data2, size2 = parse(part)
    if [t[:3] for t in tensors2] != [t[:3] for t in tensors + dtensors] or \
            size2 != data2 + base + (dsize - ddata_start):
        os.remove(part)
        sys.exit("the written file does not read back as expected")
    got = sha256_of(part)
    if os.environ.get("OUT_SHA256") and got != os.environ["OUT_SHA256"]:
        os.remove(part)
        sys.exit("output SHA-256 %s, expected %s" % (got, os.environ["OUT_SHA256"]))
    os.replace(part, out)
    print("%s: %d tensors (%d + %d), %.2f GiB, sha256 %s" % (out, len(tensors2), len(tensors), len(dtensors),
                                                            size2 / 2**30, got))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: merge_mtp.py MODEL.gguf DRAFT.gguf OUT.gguf")
    main(*sys.argv[1:])
