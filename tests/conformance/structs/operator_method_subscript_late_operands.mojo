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
    var xs = [w[0], rd(w), x[1]]
    print(len(xs))
    var y = W(3)
    var z = W(4)
    var k = pick(W(7), y[0] + z[1])
    print(k)
    var a = W(5)
    var b = W(6)
    var j = pick(b^, a[0])
    print(j)
    print("end")
