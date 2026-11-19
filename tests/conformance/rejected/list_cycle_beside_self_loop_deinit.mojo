struct A(Movable):
    var xs: List[A]
    var bs: List[B]

    def __init__(out self):
        self.xs = List[A]()
        self.bs = List[B]()


struct B(Movable):
    var as_: List[A]

    def __init__(out self):
        self.as_ = List[A]()

    def __deinit__(deinit self):
        print("drop B")


def main():
    var a = A()
    a.bs.append(B())
    a.xs.append(A())
    print(len(a.xs), len(a.bs))
