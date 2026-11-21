struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("del T", self.n)


struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(self, i: Int) -> Int:
        print("get", self.n, i)
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

    def __deinit__(deinit self):
        print("del W", self.n)


struct R(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, i: Int) -> ref [self] R:
        print("getR", self.n, i)
        return self

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

    def __deinit__(deinit self):
        print("del R", self.n)


def h() -> Int:
    var t = T(5)
    var w = W(6)
    return w[t.n]


def r() -> R:
    var x = R(2)
    var v = W(0)
    return x[v[0]]


def main():
    print(h())
    var y = r()
    print(y.n)
