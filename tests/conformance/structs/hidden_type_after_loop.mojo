@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var n = 0
    while n < 1:
        var P = 5
        n += P
    var q: P = mk()
    print(q.x, n)
