@fieldwise_init
struct B(Movable):
    var a: A


struct A(Movable):
    var bs: List[B]

    def __init__(out self):
        self.bs = List[B]()


def main():
    var a = A()
    a.bs.append(B(A()))
    print(len(a.bs))
