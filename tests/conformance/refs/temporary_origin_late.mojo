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


def own(var x: P, y: Int) -> Int:
    print("own", x.v, y)
    return x.v


def rd(x: P) -> Int:
    print("rd", x.v)
    return x.v


def tell(n: Int) -> Int:
    print(n)
    return 0


def main():
    var b = P(2)
    print(own(pick(P(1), b, True), tell(9)))
    print(rd(same(mk(3))), own(same(mk(4)), tell(8)), tell(7))
    print(vv(pick(mk(5), mk(6), True)), tell(vv(pick(mk(7), mk(8), False))))
    print("end")
