struct W(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(ref self, i: Int) -> ref [self] W:
        print("get", self.n, i)
        return self

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v

    def __bool__(var self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del W", self.n)


def main():
    var d = W(4)
    print(d[0] or False)
    var e = W(0)
    print(e[1] and True)
    print(d.n, e.n)
