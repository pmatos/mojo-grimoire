struct A(Movable):
    var id: Int
    var bs: List[B]

    def __init__(out self, id: Int):
        self.id = id
        self.bs = List[B]()

    def __deinit__(deinit self):
        print("drop A", self.id)


struct B(Movable):
    var id: Int
    var as_: List[A]

    def __init__(out self, id: Int):
        self.id = id
        self.as_ = List[A]()


def main():
    var a = A(1)
    a.bs.append(B(2))
    a.bs[0].as_.append(A(3))
    a.bs[0].as_.append(A(4))
    print(len(a.bs), len(a.bs[0].as_))
