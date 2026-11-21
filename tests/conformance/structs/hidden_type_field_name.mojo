@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


@fieldwise_init
struct Q(Copyable, Movable):
    var P: Int
    var y: P


def main():
    var q = Q(1, mk())
    print(q.P, q.y.x)
