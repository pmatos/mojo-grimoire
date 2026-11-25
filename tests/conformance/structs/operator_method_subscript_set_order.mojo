struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(self, i: Int) -> Int:
        print("get", self.n, i)
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        print("set", self.n, i, v)
        self.n = v

    def __deinit__(deinit self):
        print("del W", self.n)


def bump(mut w: W) -> Int:
    w.n += 100
    print("bump", w.n)
    return 1


def rd(w: W) -> Int:
    print("rd", w.n)
    return 2


def main():
    var w = W(1)
    var x = W(2)
    w[x[0]] = x[1]
    print("end")
