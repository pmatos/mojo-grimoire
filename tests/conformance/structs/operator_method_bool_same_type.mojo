@fieldwise_init
struct T(ImplicitlyCopyable):
    var n: Int

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del T", self.n)


def main():
    var t = T(1)
    var u = T(0)
    var x = t and u
    print("x", x.n)
    var y = u or t
    print("y", y.n)
    var z = T(2) and T(3)
    print("z", z.n)
