@fieldwise_init
struct S(Copyable):
    var k: Int
    def m(self, a: Bool, b: Int) -> Int:
        return b
    def mm(mut self, a: Int) -> Int:
        return a
    def own(var self, a: Int) -> Int:
        return a

def f(a: Int, b: Int) -> Int:
    return b
def fv(var a: S, b: Int) -> Int:
    return b
def fl(a: List[S], b: Int) -> Int:
    return b
def fvv(var a: S, var b: S) -> Int:
    return 1
def gm(mut a: S, b: S) -> Int:
    return 1
def gmv(mut a: S, var b: S) -> Int:
    return 1
def gmi(mut a: S, b: S, c: Int) -> Int:
    return 1

def idv(var a: S) -> S:
    return a^
def fS(a: S, b: Int) -> Int:
    return b
def idm(a: S, b: Int) -> S:
    return a.copy()

def gl(a: List[Int], b: Int) -> Int:
    return b
@fieldwise_init
struct T(Copyable):
    var k: Int
    def take(self, a: S, b: Int) -> Int:
        return b

def h(s: S, xs: List[Int]):
    var u = s.copy()
    var v = s.copy()
    var w = S(idv(u), 1)
def main():
    var xs: List[Int] = [1]
    h(S(1), xs)
