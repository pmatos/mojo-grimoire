@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var P = 5
    var a: Array[P, 1] = [mk()]
    print(a[0].x, P)
