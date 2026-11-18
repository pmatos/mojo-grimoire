@fieldwise_init
struct S(Movable):
    var k: Int


@fieldwise_init
struct O(Movable):
    var inner: S


def f(x: O):
    var u = x^.nope^
    print(u.k)


def main():
    f(O(S(1)))
