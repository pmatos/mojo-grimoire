struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var c: C

    def __init__(out self, var c: C):
        self.c = c^


struct C(Movable):
    var as_: Array[A, 1]

    def __init__(out self, var a: A):
        self.as_ = [a^]


def main():
    var a = A()
    a.bs.append(B(C(A())))
    print(len(a.bs))
