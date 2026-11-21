@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var q: P = mk()
    var P = 5
    print(q.x, P)
