struct A(Movable):
    var id: Int
    var bs: List[B]

    def __init__(out self, id: Int):
        self.id = id
        self.bs = List[B]()

    def __deinit__(deinit self):
        print("drop A", self.id)


struct B(Movable):
    var rows: List[List[A]]

    def __init__(out self):
        self.rows = List[List[A]]()


def main():
    var a = A(1)
    a.bs.append(B())
    a.bs[0].rows.append(List[A]())
    a.bs[0].rows[0].append(A(2))
    print(len(a.bs), len(a.bs[0].rows), len(a.bs[0].rows[0]))
