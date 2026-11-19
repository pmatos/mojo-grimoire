struct A(Movable):
    var bs: List[Array[B, 1]]

    def __init__(out self):
        self.bs = List[Array[B, 1]]()

    def __deinit__(deinit self):
        print("drop A")


struct B(Movable):
    var as_: List[A]

    def __init__(out self):
        self.as_ = List[A]()


def main():
    var a = A()
    a.bs.append([B()])
    print(len(a.bs))
