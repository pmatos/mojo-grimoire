@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(P: P) -> Int:
    return P.x


def main():
    print(f(mk()))
