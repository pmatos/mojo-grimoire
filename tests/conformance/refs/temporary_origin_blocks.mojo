@fieldwise_init
struct T(Movable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def same(ref x: T) -> ref [x] T:
    return x


def pick(ref a: T, ref b: T, first: Bool) -> ref [a, b] T:
    if first:
        return a
    return b


def pz(x: T) -> Int:
    print("pz", x.v)
    return x.v


def vv(ref x: T) -> Int:
    return x.v


def mk(v: Int) -> T:
    print("mk", v)
    return T(v)


def tell(n: Int) -> Int:
    print(n)
    return 0


def main():
    ref r = same(mk(1))
    var i = 0
    while i < 2:
        print(vv(r), i)
        i += 1
    ref s = same(mk(2))
    if i == 0:
        print(vv(s))
    else:
        print("else")
    while i < 4:
        ref t = same(mk(i))
        print("body", vv(t))
        i += 1
    print("end")
