struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del T", self.n)


@fieldwise_init
struct H(Movable):
    var t: T
    var u: T


def main():
    var h = H(T(0), T(7))
    h.u = h.t and h.u
    print(h.u.n)
