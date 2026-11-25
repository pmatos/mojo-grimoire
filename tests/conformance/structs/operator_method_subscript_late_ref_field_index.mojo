struct K(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("del K", self.n)


struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, i: Int) -> ref [self] W:
        print("get", self.n, i)
        return self

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

    def __deinit__(deinit self):
        print("del W", self.n)


def sh(a: W, b: Int) -> Int:
    print("sh", a.n, b)
    return a.n


def main():
    var w = W(1)
    var t = K(4)
    print(sh(w[t.n], 5))
    print("end")
