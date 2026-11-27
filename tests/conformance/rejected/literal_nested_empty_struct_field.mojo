@fieldwise_init
struct S(Movable):
    var k: Int


@fieldwise_init
struct T(Movable):
    var v: S


def main():
    var t = T([[]])
    print(t.v.k)
