@fieldwise_init
struct S(Movable):
    var k: Int


def f(s: S):
    ref t = s
    var u = t^
    print(u.k)


def main():
    var s = S(7)
    f(s)
