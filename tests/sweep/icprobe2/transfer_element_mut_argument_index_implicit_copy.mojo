@fieldwise_init
struct S(Movable):
    var k: Int


def g(mut x: S):
    x.k += 1


def own(var x: S) -> Int:
    return x.k


def main():
    var l: List[S] = [S(1)]
    var s = S(0)
    g(l[own(s)]^)
