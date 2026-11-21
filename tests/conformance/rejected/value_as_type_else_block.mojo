@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var P = 5
    if P > 3:
        print(P)
    else:
        var q: P = mk()
        print(q.x)
