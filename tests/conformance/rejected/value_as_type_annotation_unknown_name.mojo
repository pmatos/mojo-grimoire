@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var Nope = 5
    var q: Nope = mk()
    print(q.x, Nope)
