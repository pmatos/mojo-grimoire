struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var id: Int
    var cs: List[C]

    def __init__(out self, id: Int):
        self.id = id
        self.cs = List[C]()

    def __deinit__(deinit self):
        print("drop B", self.id)


struct C(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


def main():
    var a = A()
    a.bs.append(B(1))
    a.bs[0].cs.append(C())
    a.bs[0].cs[0].bs.append(B(2))
    print(len(a.bs), len(a.bs[0].cs[0].bs))
