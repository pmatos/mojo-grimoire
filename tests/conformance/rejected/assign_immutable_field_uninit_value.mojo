@fieldwise_init
struct P(Movable):
    var a: Int


def f(p: P):
    var j: Int
    p.a = j


def main():
    f(P(1))
