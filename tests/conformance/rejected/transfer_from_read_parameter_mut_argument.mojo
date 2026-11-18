@fieldwise_init
struct S(Movable):
    var k: Int


def bump(mut x: S):
    x.k += 1


def f(t: S):
    bump(t^)


def main():
    var s = S(7)
    f(s)
    print(s.k)
