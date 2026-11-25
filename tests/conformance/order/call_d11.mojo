@fieldwise_init
struct S(Copyable):
    var k: Int
    def mm(mut self, a: Int) -> Int:
        return a
    def mv(mut self, var b: S) -> Int:
        return 1

def gm(mut a: S, b: Int) -> Int:
    return 1

def gm2(b: Int, mut a: S) -> Int:
    return 1

def gv(var a: S, mut c: S) -> Int:
    return 1

def gx(mut a: S, mut b: S, c: Bool) -> Int:
    return 1

def h(s: S, t: S):
    var u = s.copy()
    print(gx(u, u, 1))

def main():
    var s = S(1)
    var t = S(2)
    h(s, t)
