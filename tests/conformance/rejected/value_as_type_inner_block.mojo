@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var P = 5
    if True:
        var q: P = mk()
        print(q.x)
    print(P)
