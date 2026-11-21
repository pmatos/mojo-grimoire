struct S(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(var self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del", self.n)


def mk(n: Int) -> S:
    return S(n)


def main():
    print(mk(2) and True)
    print(S(0) or False)
    var b = S(3)
    print(b^ and True)
    var z = S(0)
    var c = S(5)
    print((z or c) and True)
    print(True and mk(6))
    print(not mk(7))
    var d = S(8)
    print(d and False)
    var r = mk(0) or mk(9)
    print(r.n)
    print("end")
