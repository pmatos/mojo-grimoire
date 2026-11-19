struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


struct B(Movable):
    var cs: List[C]

    def __init__(out self):
        self.cs = List[C]()


struct C(Movable):
    var id: Int
    var as_: List[A]

    def __init__(out self, id: Int):
        self.id = id
        self.as_ = List[A]()

    def __deinit__(deinit self):
        print("drop C", self.id)


def main():
    var a = A()
    a.bs.append(B())
    a.bs[0].cs.append(C(1))
    a.bs[0].cs.append(C(2))
    a.bs[0].cs[0].as_.append(A())
    print(len(a.bs[0].cs), len(a.bs[0].cs[0].as_))
