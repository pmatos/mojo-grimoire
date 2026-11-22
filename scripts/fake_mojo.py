#!/usr/bin/env python3
"""A stand-in compiler for scripts/test_conformance.py, called as
`fake_mojo.py build [FLAG...] PROGRAM -o BINARY`.

It rejects a program that contains REJECT, and builds any other into a
script that prints its PRINT lines and fails when it contains FAIL; it
prints the text of a `print("text")` too. A line `LEVEL L text` prints text
only when built with the flag L, and `CRASH L` makes the build with L crash
with no error. A failed run built with -O0 also writes the runtime's
assertion line.
"""

import os
import sys
from pathlib import Path

args = sys.argv[2:]
path = next(a for a in args if a.endswith(".mojo"))
binary = args[args.index("-o") + 1]
src = Path(path).read_text()
for line in src.splitlines():
    if line.startswith("# CRASH ") and line.split()[2] in args:
        print("Segmentation fault", file=sys.stderr)
        sys.exit(139)
if "REJECT" in src:
    print(path + ":1:1: error: use of uninitialized value 'a'", file=sys.stderr)
    sys.exit(1)
out = [line.split("PRINT ", 1)[1] for line in src.splitlines() if "PRINT " in line]
out += [line.split('"')[1] for line in src.splitlines() if 'print("' in line]
for line in src.splitlines():
    if line.startswith("# LEVEL ") and line.split()[2] in args:
        out.append(line.split(None, 3)[3])
code = 1 if "FAIL" in src else 0
if code and "-O0" in args:
    out.append("At: " + path + ":1:1: Assert Error: boom")
with open(binary, "w") as f:
    f.write("#!/bin/sh\n" + "".join(f"echo '{x}'\n" for x in out) + f"exit {code}\n")
os.chmod(binary, 0o755)
