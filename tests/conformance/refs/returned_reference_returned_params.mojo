@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def pick(ref a: P, ref b: P, first: Bool) -> ref[a, b] P:
    if first:
        return a
    return b


def from_params(var a: P, var b: P) -> P:
    return pick(a, b, True)


def from_both(var a: P) -> P:
    var b = P(2)
    return pick(a, b, True)


def main():
    var p = from_params(P(1), P(2))
    print(p.v)
    var q = from_both(P(1))
    print(q.v)
