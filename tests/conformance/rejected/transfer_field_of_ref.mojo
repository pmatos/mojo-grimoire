@fieldwise_init
struct S(Movable):
    var k: Int


@fieldwise_init
struct O(Movable):
    var inner: S


def main():
    var o = O(S(7))
    ref t = o
    var u = t.inner^
    print(u.k)
