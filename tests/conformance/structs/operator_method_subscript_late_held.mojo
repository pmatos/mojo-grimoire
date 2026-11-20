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


def bump(mut w: W) -> Int:
    w.n += 100
    print("bump", w.n)
    return 1


def g(a: Int, b: Int) -> Int:
    return a + b


def rd(w: W) -> Int:
    print("rd", w.n)
    return 0


def main():
    var w = W(1)
    var x = W(2)
    print(w[0] + x[rd(w)])
    var a = W(3)
    var b = W(4)
    print(a[0], b[bump(a)])
    var c = W(5)
    var d = W(6)
    var xs = [c[0], d[g(0, bump(c))]]
    print(len(xs))
    print("end")
