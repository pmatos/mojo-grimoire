struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Bool:
        return self.n != 0

    def __add__(self, o: Self) -> Self:
        return T(self.n + o.n)

    def me(ref self) -> ref [self] T:
        return self


struct H(Movable):
    var t: T
    var u: T

    def __init__(out self, var t: T, var u: T):
        self.t = t^
        self.u = u^



def idT(x: T) -> T:
    return T(x.n)


def same(ref x: T) -> ref [x] T:
    return x


def samer(x: T) -> ref [x] T:
    return x


def samem(mut x: T) -> ref [x] T:
    return x


def bump(mut k: Int) -> Int:
    k += 1
    return 0


def touch(mut xs: List[T]) -> T:
    xs.append(T(7))
    return T(3)


def touchi(mut xs: List[T]) -> Int:
    xs.append(T(8))
    return 0


def take(var t: T) -> Int:
    return 0


struct G(Movable):
    var ts: List[T]
    var k: T

    def __init__(out self, var ts: List[T], var k: T):
        self.ts = ts^
        self.k = k^


def mk(n: Int) -> T:
    return T(n)


def main():
    var a = T(0)
    var b = T(2)
    var h = H(T(0), T(5))
    var xs: List[T] = [T(0), T(4)]
    var k = 0
    ref r = xs[0]
    ref ys = xs
    var g = G([T(0), T(1)], T(3))
    var res = samer(a) or b
    print(res.n)
