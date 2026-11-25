struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(self, i: Int) -> Bool:
        print("get", self.n, i)
        return self.n > i

    def __setitem__(mut self, i: Int, v: Bool):
        pass

    def __deinit__(deinit self):
        print("del W", self.n)


struct V(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(self, i: Int) -> Int:
        print("getV", self.n, i)
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        pass

    def __deinit__(deinit self):
        print("del V", self.n)

def pr(k: Int) -> Int:
    print("pr", k)
    return k


def main():
    var w = W(1)
    var x = W(2)
    var r = w[0] or x[5]
    print(r)
    var y = W(3)
    var z = W(4)
    var s = y[5] and z[0]
    print(s)
    var u = W(5)
    var q = u[0] or u[9]
    print(q)
    var a = W(6)
    var t = a[pr(0)] or False
    print(t)
    var b = W(7)
    var v = V(0)
    var c = b[v[pr(1)]] or False
    print(c)
    print("end")
