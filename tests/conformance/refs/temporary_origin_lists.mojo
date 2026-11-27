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


def lst(ref xs: List[T]) -> ref [xs] List[T]:
    return xs


def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def main():
    print(len(first([1, 2])))
    ref r = first([1, 2, 3])
    print(len(r))
    print(len(lst([T(1), T(2)])))
    ref s = lst([T(3)])
    print(len(s), s[0].v)
    print("end")
