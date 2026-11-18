struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var others: Array[A, 1]

    def __init__(out self, var a: A):
        self.others = [a^]


def main():
    var a = A()
    a.bs.append(B(A()))
    print(len(a.bs))
