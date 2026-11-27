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
def main():
    var y = T(5)
    print(vv(pick(pick(y, T(1), True), y, False)))
