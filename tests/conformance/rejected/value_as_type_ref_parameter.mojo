@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(ref P: Int, q: P) -> Int:
    return q.x + P


def main():
    var n = 1
    print(f(n, mk()))
