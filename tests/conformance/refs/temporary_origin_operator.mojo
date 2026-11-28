@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __add__(self, o: Self) -> Self:
        print("add", self.v, o.v)
        return P(self.v + o.v)

    def __bool__(self) -> Bool:
        print("bool", self.v)
        return self.v != 0

    def __deinit__(deinit self):
        print("drop", self.v)


def same(ref x: P) -> ref [x] P:
    return x


def pick(ref a: P, ref b: P, first: Bool) -> ref [a, b] P:
    if first:
        return a
    return b


def mk(v: Int) -> P:
    print("mk", v)
    return P(v)


def vv(ref x: P) -> Int:
    return x.v


def main():
    var q = same(P(1)) + same(P(2))
    print(q.v)
    var a = P(7)
    var r = same(a) + same(mk(3))
    print(r.v, a.v)
    var s = same(mk(4)) + mk(5)
    print(s.v)
    print("end")
