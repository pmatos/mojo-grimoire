@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(P: Int, q: P):
    print(q.x, P)


def main():
    f(5, mk())
