struct S(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("del S", self.n)


@fieldwise_init
struct W(Copyable):
    var a: Int

    def __getitem__(self, i: Int) -> Int:
        print("get", i)
        return self.a + i

    def __setitem__(mut self, i: Int, v: Int):
        self.a = v


def h(s: S) -> Int:
    print("h", s.n)
    return s.n


def g(s: S) -> Int:
    print("g", s.n)
    return s.n * 10


def k(a: Int, b: Int) -> Int:
    return a + b


def main():
    var w = W(100)
    var s = S(7)
    print(w[h(s)], g(s))
    var t = S(8)
    var r = w[h(t)] + g(t)
    print(r)
    var u = S(9)
    print(k(w[h(u)], g(u)))
    var v = S(3)
    print(w[v.n + 0], g(v))
