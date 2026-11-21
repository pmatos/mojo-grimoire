# D-0010 in detail: one-element arrays compare equal beside a printing destructor

This page holds the program and the evidence for
[D-0010](decision-log.md#d-0010-one-element-arrays-compare-equal-beside-a-printing-destructor-provisional).
The decision log keeps only the summary, so that it stays within the
file-size budget.

## Program

`tests/conformance/arrays/compare_beside_printing_deinit.mojo`, listed in
`known.json` under D-0010:

```mojo
@fieldwise_init
struct H(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("del", self.n)


def get(h: H) -> Int:
    return h.n


def main():
    var h = H(1)
    var g = H(2)
    print([get(h)] == [get(g)], [get(h)] < [get(g)])
```

The pinned nightly prints `del 1`, `del 2`, `True False`. The model prints
`del 1`, `del 2`, `False True`.

## Compiler

These runs were made on 2026-11-21 with the pinned nightly
1.3.0.dev2026111905, unless a version is named.

- The default build prints `True False`. The arrays compare as equal,
  whatever they hold:
  - `[2] == [1]` is `True`, and `[1] == [1]` is `True`;
  - `[1] < [2]` is `False`, and `[2] < [1]` is `False`.
- The arrays themselves are built correctly:
  `var a = [get(h)]; var b = [get(g)]; print(a[0], b[0], a == b, a < b)`
  prints `1 2 True False`.
- `-O0` prints the right `False True`, and so does `-D ASSERT=all`.
- Mojo 1.2.0 prints `True False`, and so do the nightlies
  1.3.0.dev2026111705 and 1.3.0.dev2026112017.
- In each of these controls the answers are right:
  - the destructor is `pass`;
  - the values come from parameters or from `pop` instead of from `get`;
  - the arrays have two elements, as in `[get(h), 0] == [get(g), 0]`;
  - the values are compared as plain `Int`s, as in `get(h) == get(g)`.
- When the arrays are fields of such a struct, `print(k.a > g.a)` with
  `[2]` and `[1]` prints `False`.
- The probes are recorded on #235.

## Evidence

The fixed compiler compares the elements one by one:
- that is the pin's own result at `-O0` and in every control above;
- it is how `Array`'s comparisons are defined, and what #166 ruled they do.

Only the optimized build disagrees. So the human ruled on 2026-11-21 that
this is a compiler bug (#235). The ruling is provisional, until the human
has discussed it with Modular.
