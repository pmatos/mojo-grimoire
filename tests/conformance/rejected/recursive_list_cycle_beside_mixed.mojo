struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var a: A
    var xs: List[A]

    def __init__(out self, var a: A):
        self.a = a^
        self.xs = List[A]()


def main():
    var a = A()
    a.bs.append(B(A()))
    print(len(a.bs))
