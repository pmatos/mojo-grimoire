struct A(Movable):
    var id: Int
    var bs: List[B]

    def __init__(out self, id: Int):
        self.id = id
        self.bs = List[B]()

    def __deinit__(deinit self):
        print("drop A", self.id)


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^

    def __deinit__(deinit self):
        print("drop B", self.a.id)


def main():
    var outer = A(1)
    outer.bs.append(B(A(2)))
    outer.bs.append(B(A(3)))
    outer.bs[0].a.bs.append(B(A(4)))
    print(len(outer.bs), len(outer.bs[0].a.bs))
    outer.bs.pop()
    print("popped")
