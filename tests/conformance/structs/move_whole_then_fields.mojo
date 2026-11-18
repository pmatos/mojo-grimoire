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
    var c = s^
    s.lo = Pair(5, 6)
    var k = s.lo^
    print(c.hi.x, k.y)
