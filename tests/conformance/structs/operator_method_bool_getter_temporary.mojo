struct K(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("del K", self.n)


struct V(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(self, k: K) -> Bool:
        print("get", self.n, k.n)
        return self.n + k.n > 0

    def __setitem__(mut self, k: K, v: Bool):
        pass


def main():
    var v = V(1)
    var r = v[K(5)] or False
    print(r)
    var s = v[K(6)] and False
    print(s)
