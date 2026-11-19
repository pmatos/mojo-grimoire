struct A(Movable):
    var bs: Array[List[B], 1]

    def __init__(out self):
        self.bs = [List[B]()]

    def __deinit__(deinit self):
        print("drop A")


struct B(Movable):
    var as_: List[A]

    def __init__(out self):
        self.as_ = List[A]()


def main():
    var a = A()
    a.bs[0].append(B())
    print(len(a.bs[0]))
