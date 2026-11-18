struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var others: List[A]

    def __init__(out self):
        self.others = List[A]()


def main():
    var a = A()
    a.bs.append(B())
    a.bs[0].others.append(A())
    print(len(a.bs), len(a.bs[0].others))
