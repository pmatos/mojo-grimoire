struct A(Copyable, Movable):
    var id: Int
    var xs: List[A]

    def __init__(out self, id: Int):
        self.id = id
        self.xs = List[A]()

    def __deinit__(deinit self):
        print("drop A", self.id)


def main():
    var a = A(1)
    a.xs.append(A(2))
    var c = a.copy()
    c.xs.append(A(3))
    print(len(a.xs), len(c.xs))
