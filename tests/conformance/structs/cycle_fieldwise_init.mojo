struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


@fieldwise_init
struct B(Movable):
    var a: A


def main():
    var outer = A()
    outer.bs.append(B(A()))
    print(len(outer.bs))
