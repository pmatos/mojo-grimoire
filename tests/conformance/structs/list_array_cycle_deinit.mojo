struct A(Movable):
    var id: Int
    var bs: List[B]

    def __init__(out self, id: Int):
        self.id = id
        self.bs = List[B]()


struct B(Movable):
    var others: Array[A, 1]

    def __init__(out self, var a: A):
        self.others = [a^]

    def __deinit__(deinit self):
        print("drop B")


def main():
    var a = A(1)
    a.bs.append(B(A(2)))
    print(len(a.bs), a.bs[0].others[0].id)
