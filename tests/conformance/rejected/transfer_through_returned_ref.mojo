@fieldwise_init
struct S(Movable):
    var k: Int


def same(ref x: S) -> ref [x] S:
    return x


def main():
    var s = S(7)
    ref t = same(s)
    var u = t^
    print(u.k)
