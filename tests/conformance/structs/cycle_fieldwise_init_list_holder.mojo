@fieldwise_init
struct A(Movable):
    var bs: List[B]


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var outer = A(List[B]())
    outer.bs.append(B(A(List[B]())))
    print(len(outer.bs))
