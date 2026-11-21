@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var p = 5
    ref P = p
    var q: P = mk()
    print(q.x, P)
