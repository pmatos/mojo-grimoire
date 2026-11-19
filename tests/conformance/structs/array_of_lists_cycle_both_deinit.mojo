struct A(Movable):
    var id: Int
    var bs: Array[List[B], 1]

    def __init__(out self, id: Int):
        self.id = id
        self.bs = [List[B]()]

    def __deinit__(deinit self):
        print("drop A", self.id)


struct B(Movable):
    var id: Int
    var as_: List[A]

    def __init__(out self, id: Int):
        self.id = id
        self.as_ = List[A]()

    def __deinit__(deinit self):
        print("drop B", self.id)


def main():
    var a = A(1)
    a.bs[0].append(B(2))
    a.bs[0][0].as_.append(A(3))
    print(len(a.bs[0]), len(a.bs[0][0].as_))
