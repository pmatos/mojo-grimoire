@fieldwise_init
struct S(Movable):
    var k: Int


def bump(mut x: S):
    x.k += 1


def main():
    var l: List[S] = [S(1)]
    ref t = l
    bump(t[-1]^)
    print(l[0].k)
