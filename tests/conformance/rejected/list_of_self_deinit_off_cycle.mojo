struct D(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __deinit__(deinit self):
        print("drop D", self.n)


struct A(Movable):
    var d: D
    var xs: List[A]

    def __init__(out self, n: Int):
        self.d = D(n)
        self.xs = List[A]()


def main():
    var a = A(1)
    a.xs.append(A(2))
    print(len(a.xs))
