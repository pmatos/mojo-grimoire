@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(Int: Int):
    var x: Int = 3
    print(x, Int)


def main():
    f(5)
