@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    if True:
        var P = 5
        print(P)
    var q: P = mk()
    print(q.x)
