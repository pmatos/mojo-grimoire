@fieldwise_init
struct A(Movable):
    var bs: List[B]


@fieldwise_init
struct B(Movable):
    var a: A


def main():
    var outer = A(List[B]())
    outer.bs.append(B(A(List[B]())))
    print(len(outer.bs))
