struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(self, i: Int) -> Bool:
        print("get", self.n, i)
        return self.n + i > 0

    def __setitem__(mut self, i: Int, v: Bool):
        pass

    def __deinit__(deinit self):
        print("del W", self.n)


struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("del T", self.n)


def main():
    var t = T(-5)
    var w = W(2)
    var s = w[t.n] or False
    print(s)
