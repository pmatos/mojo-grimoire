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
    var xs: List[P] = [same(mk(1)), same(mk(2))]
    print(len(xs))
    var ys = [0, 0, 0]
    ys[vv(same(mk(1)))] = 7
    print(ys[1])
    print("end")
