#!/usr/bin/env python3
"""Convert a flat binary into a $readmemh file: one 32-bit little-endian word per line.

    bin2mem.py in.bin out.mem [min_words]

An empty / missing input produces a file with a single zero word.
"""
import sys, os

def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    min_words = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    data = open(src, 'rb').read() if os.path.exists(src) else b''
    data += b'\x00' * (-len(data) % 4)
    words = [int.from_bytes(data[i:i+4], 'little') for i in range(0, len(data), 4)]
    words += [0] * max(0, min_words - len(words))
    with open(dst, 'w') as f:
        for w in words:
            f.write(f'{w:08x}\n')

if __name__ == '__main__':
    main()
