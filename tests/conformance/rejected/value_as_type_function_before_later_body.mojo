@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(P: Int, q: P):
    print(P)


def g():
    print(zz)


def main():
    g()
