@fieldwise_init
struct S(Copyable):
    var k: Int
    def m(self, a: Bool, b: Int) -> Int:
        return b
    def mm(mut self, a: Int) -> Int:
        return a

@fieldwise_init
struct P(Movable):
    var x: Int

def f(a: Bool, b: Int) -> Int:
    return b

def fv(var s: S, a: Bool) -> Int:
    return 1

def fv2(a: Bool, var s: S) -> Int:
    return 1

def g(mut a: List[Int], b: List[Int]) -> Int:
    return 1

def gm(mut a: S, b: Int) -> Int:
    return 1

def main():
    var s = S(1)
    var xs: List[Int] = [1]
    var u: Int
    var l: List[S] = [S(1)]
    print(f(1, s^.k))
