# D-0012 in detail: arrays of arrays of one-element arrays compare wrongly at -O3

This page holds the program and the evidence for
[D-0012](decision-log.md#d-0012-arrays-of-arrays-of-one-element-arrays-compare-wrongly-at--o3-provisional).
The decision log keeps only the summary, so that it stays within the
file-size budget.

## Program

`tests/conformance/arrays/compare_deep_one_element.mojo`, listed in
`known.json` under D-0012:

```mojo
def main():
    var e = [[[1]]]
    var z = [[[0]]]
    print(e > z, e == z)
```

The pinned nightly prints `False False`. The model prints `True False`.

## Compiler

These runs were made on 2026-11-21 with the pinned nightly
1.3.0.dev2026111905, each program built with `mojo build` at `-O0`, `-O1`,
`-O2`, `-O3` and with no flag, the default, which is `-O3`.

| Body of `main` | `-O3`, the default | `-O0`, `-O1`, `-O2` |
|---|---|---|
| the program above | `False False` | `True False` |
| the same with `print(e > z, e < z, e != z)` | `False False True` | `True False True` |
| `print(e > z)` alone | `True` | `True` |
| four levels: `[[[[1]]]]` against `[[[[0]]]]` | `False False` | `True False` |
| `Bool`s: `[[[True]]]` against `[[[False]]]` | `False False` | `True False` |
| two elements: `[[[1, 2]]]` against `[[[0, 2]]]` | `True False` | `True False` |
| two levels: `[[1]]` against `[[0]]` | `True False` | `True False` |
| one level: `[1]` against `[0]` | `True False` | `True False` |

So `e > z` is wrong at `-O3` only when another comparison of the same
arrays is printed with it, and only for arrays three or more levels deep
with one element at each level. No printing `__deinit__` is needed, unlike
D-0010.

Mojo 1.2.0 and the nightly 1.3.0.dev2026112017 give the same results at
every level. The probes are recorded on #257.

## Evidence

The fixed compiler compares the elements one by one:
- that is the pin's own result at `-O0`, `-O1` and `-O2`, and at `-O3`
  for two-element arrays and for arrays less than three levels deep;
- it is how `Array`'s comparisons are defined, and what #166 ruled they do.

Only the default optimized build disagrees. So the human ruled on
2026-11-21 that this is a compiler bug, with an entry of its own rather
than a widening of D-0010 (#257). The ruling is provisional, until the
human has discussed it with Modular.
