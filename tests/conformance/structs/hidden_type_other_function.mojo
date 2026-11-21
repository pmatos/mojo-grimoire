@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def h(x: Int) -> Int:
    var P = x
    return P


def main():
    var q: P = mk()
    print(q.x, h(2))
