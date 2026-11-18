@fieldwise_init
struct S(Movable):
    var k: Int


def g(mut x: S):
    x.k += 1


def main():
    var l: List[S] = [S(1)]
    g(l[0]^.nope^)
