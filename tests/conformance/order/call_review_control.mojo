@fieldwise_init
struct S(Copyable):
    var k: Int
    def mm(mut self, a: Int) -> Int:
        return a
    def mvb(self, var b: S, c: Bool) -> Int:
        return 1
    def mr(mut self, b: S, c: Bool) -> Int:
        return 1
def fv(var s: S, a: Bool) -> Int:
    return 1
def fv2(var s: S) -> S:
    return s^
def fs(var a: S, b: Int) -> Int:
    return 1
def gm(mut a: S, b: Int) -> Int:
    return 1
def gr(mut a: S, b: S) -> Int:
    return 1
def gx2(mut a: S, mut b: S, var c: S) -> Int:
    return 1
def lk(xs: List[S], b: Bool) -> Int:
    return 1
def fb(var s: S) -> Bool:
    return True
def f2(a: Bool, b: Int) -> Int:
    return b
def h(s: S, xs: List[Int]):
    var u = s.copy()
    var w = s.copy()
    print(fv(fv2(u^), True))
    print(fs(w.copy(), 1))
    print(s.mvb(s.copy(), True))
    print(lk([s.copy()], True))
    print(f2(fb(s.copy()), 1))
    var z = s.copy()
    print(gm(z, 1))
    print(gr(z, s))
    print(z.mr(s, True))
def main():
    var xs: List[Int] = [1]
    h(S(1), xs)
