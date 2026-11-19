struct A(Movable):
    var id: Int
    var bs: Array[B, 1]

    def __init__(out self, id: Int, var b: B):
        self.id = id
        self.bs = [b^]

    def __deinit__(deinit self):
        print("drop A", self.id)


struct B(Movable):
    var as_: List[A]

    def __init__(out self):
        self.as_ = List[A]()


def main():
    var a = A(1, B())
    a.bs[0].as_.append(A(2, B()))
    print(len(a.bs[0].as_))
