@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(P: Int) -> P:
    return mk()


def main():
    var q = f(5)
    print(q.x)
