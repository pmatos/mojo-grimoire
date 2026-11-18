struct A(Movable):
    var bs: List[B]
    var xs: List[A]

    def __init__(out self):
        self.bs = List[B]()
        self.xs = List[A]()


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var a = A()
    a.bs.append(B(A()))
    print(len(a.bs))
