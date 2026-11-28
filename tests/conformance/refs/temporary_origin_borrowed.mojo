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
    print(pz(same(T(1))))
    var a = T(10)
    print(tell(100), pz(same(mk(2))), pz(a), tell(300))
    var c = T(5)
    print(pz(pick(T(3), c, False)))
    print(pz(pick(mk(6), mk(7), True)))
    print(vv(same(T(8))), tell(vv(same(T(9)))))
    print("end")
