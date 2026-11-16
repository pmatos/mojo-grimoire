@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def pick(ref a: P, ref b: P, first: Bool) -> ref[a, b] P:
    if first:
        return a
    return b


def get() -> P:
    var a = P(1)
    var b = P(2)
    return pick(a, b, True)


def main():
    var p = get()
    print(p.v)
    var q = P(5)
    var r = P(6)
    var s = pick(q, r, False)
    print(s.v)
