struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var cs: List[C]

    def __init__(out self):
        self.cs = List[C]()


struct C(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var a = A()
    a.bs.append(B())
    a.bs[0].cs.append(C(A()))
    print(len(a.bs), len(a.bs[0].cs))
