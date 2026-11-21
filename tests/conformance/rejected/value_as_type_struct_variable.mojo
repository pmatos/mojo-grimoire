@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var P = mk()
    var q: P = mk()
    print(q.x, P.x)
