struct C(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


struct B(Movable):
    var c: C

    def __init__(out self, var c: C):
        self.c = c^


struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


def main():
    var a = A()
    a.bs.append(B(C(A())))
    print(len(a.bs))
