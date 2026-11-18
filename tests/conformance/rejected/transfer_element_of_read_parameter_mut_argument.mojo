@fieldwise_init
struct S(Movable):
    var k: Int


def g(mut x: S):
    x.k += 1


def f(x: List[S]):
    g(x[0]^)


def main():
    var l: List[S] = [S(1)]
    f(l)
