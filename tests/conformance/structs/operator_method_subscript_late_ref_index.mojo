struct K(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("del K", self.n)


def pr(k: Int) -> Int:
    print("pr", k)
    return k


struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, k: K) -> ref [self] W:
        print("get", self.n, k.n)
        return self

    def __setitem__(mut self, k: K, v: Int):
        print("set", self.n, k.n, v)
        self.n = v

    def __deinit__(deinit self):
        print("del W", self.n)


def sh(a: W, b: Int) -> Int:
    print("sh", a.n, b)
    return a.n


def sh2(b: Int, a: W) -> Int:
    print("sh2", a.n, b)
    return a.n


def main():
    var w = W(1)
    print(sh(w[K(2)], pr(3)))
    var k = K(4)
    print(sh(w[k], pr(5)))
    var x = W(6)
    var j = K(7)
    print(sh2(pr(8), x[j]))
    var y = W(9)
    print(sh(y[K(10)], sh(y[K(11)], 12)))
    print("end")
