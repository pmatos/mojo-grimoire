@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(q: P, P: Int):
    print(q.x, P)


def main():
    f(mk(), 5)
