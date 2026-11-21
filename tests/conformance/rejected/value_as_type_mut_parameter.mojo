@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(mut P: Int):
    var q: P = mk()
    print(q.x)


def main():
    var n = 5
    f(n)
