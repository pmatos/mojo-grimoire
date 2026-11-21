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


def rd(w: W) -> Int:
    print("rd", w.n)
    return 0


def pick(var a: W, b: Int) -> Int:
    return a.n + b


def main():
    var w = W(1)
    var x = W(2)
    var k = rd(x) + w[0] + x[1]
    print(k)
    var v = W(0)
    var u = W(5)
    var j = u[v[1]] + rd(v)
    print(j)
    print("end")
