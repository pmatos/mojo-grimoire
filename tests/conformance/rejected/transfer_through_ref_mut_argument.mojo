@fieldwise_init
struct S(Movable):
    var k: Int


def bump(mut x: S):
    x.k += 1


def main():
    var s = S(7)
    ref t = s
    bump(t^)
    print(s.k)
