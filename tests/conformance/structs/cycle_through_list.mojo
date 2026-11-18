struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var outer = A()
    outer.bs.append(B(A()))
    outer.bs.append(B(A()))
    print(len(outer.bs))
    print(len(outer.bs[0].a.bs))
