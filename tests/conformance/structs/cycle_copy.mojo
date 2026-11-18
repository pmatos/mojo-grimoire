struct A(Copyable, Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Copyable, Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var outer = A()
    outer.bs.append(B(A()))
    var c = outer.copy()
    c.bs.append(B(A()))
    print(len(outer.bs), len(c.bs))
