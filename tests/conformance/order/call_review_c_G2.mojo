@fieldwise_init
struct S(Copyable):
    var k: Int
    def m(self, a: Bool, b: Int) -> Int:
        return b
    def mm(mut self, a: Int) -> Int:
        return a
    def me(var self) -> S:
        return self^

def g(var s: S) -> S:
    return s^

def fs(a: S, b: Bool) -> Int:
    return 1

def fi(a: Int, b: Bool) -> Int:
    return 1

def hm(mut a: S, mut b: S) -> Int:
    return 1

def hv(mut a: S, var b: S) -> Int:
    return 1

def gi(var s: S) -> Int:
    return 1

def gv(var a: S, var b: S) -> Int:
    return 1

def gmv(var a: S, mut b: S) -> Int:
    return 1

@fieldwise_init
struct T(Copyable):
    var k: Int
    def __add__(var self, o: Bool) -> Int:
        return 1
    def __sub__(self, var o: T) -> Int:
        return 1
    def __iadd__(mut self, o: Bool):
        pass

def fl(a: List[S], b: Bool) -> Int:
    return 1

def main():
    var u = S(1)
    var v = S(2)
    print(fl([g(u)], 1))
