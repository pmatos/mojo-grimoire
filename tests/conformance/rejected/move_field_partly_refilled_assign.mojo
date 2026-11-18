@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Seg(Movable):
    var lo: Pair
    var hi: Pair


def main():
    var s = Seg(Pair(1, 2), Pair(3, 4))
    var k = s.lo^
    s.lo.x = 5
    print(s.lo.x, k.y)
    s.lo = Pair(7, 8)
    print(s.lo.x, s.hi.y)
