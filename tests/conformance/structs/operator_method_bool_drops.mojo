struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del T", self.n)


def mk(k: Int) -> T:
    print("mk", k)
    return T(k)


def main():
    var t = T(1)
    var x = t and mk(2)
    print(x.n)
    var u = T(3)
    var s = T(4)
    var y = s or u
    print(y.n)
    var a = T(0)
    var b = T(5)
    var z = (a or b) and mk(6)
    print(z.n)
    var c = T(7)
    var w = mk(0) or c
    print(w.n)
    print("end")
