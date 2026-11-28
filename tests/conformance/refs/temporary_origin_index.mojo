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

def tell(n: Int) -> Int:
    print(n)
    return n


def main():
    var ys = [0, 0, 0]
    ys[vv(same(mk(1)))] = tell(5)
    print(ys[vv(same(mk(2)))], tell(6))
    var bs = [True, True, False]
    var i = 0
    while bs[vv(same(mk(i)))]:
        i += 1
    print("end", i)
