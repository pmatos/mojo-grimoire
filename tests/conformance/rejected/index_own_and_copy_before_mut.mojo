@fieldwise_init
struct T(Movable):
    var n: Int

    def __bool__(var self) -> Bool:
        return self.n != 0


def pz(x: T) -> Int:
    return 0


def bump(mut x: T) -> T:
    return T(x.n)


def f(t0: T, t1: T):
    var xs: List[Int] = [1]
    print(xs[pz(t1 and bump(t0))])


def main():
    print(1)
