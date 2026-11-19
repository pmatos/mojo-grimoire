struct A(Movable):
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
    a.xs[0].xs.append(A(3))
    a.xs.append(A(4))
    print(len(a.xs), len(a.xs[0].xs))
    a.xs.pop()
    print("popped")
