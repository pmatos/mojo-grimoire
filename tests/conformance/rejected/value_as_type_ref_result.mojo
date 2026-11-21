@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def g(ref a: P, P: Int) -> ref[a] P:
    return a


def main():
    var p = mk()
    ref r = g(p, 5)
    print(r.x)
