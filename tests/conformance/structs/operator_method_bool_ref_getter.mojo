struct W(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, i: Int) -> ref [self] W:
        print("get", self.n, i)
        return self

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del W", self.n)


def main():
    var d = W(4)
    var e = W(5)
    var x = d[0] and e[0]
    print(x.n)
    var f = W(6)
    var g = W(7)
    var y = f[0] and g[0]
    print(y.n, f.n)
    print("end")
