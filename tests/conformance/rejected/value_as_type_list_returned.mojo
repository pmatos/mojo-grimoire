@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(P: Int) -> List[Int]:
    return List[P]()


def main():
    print(len(f(1)))
