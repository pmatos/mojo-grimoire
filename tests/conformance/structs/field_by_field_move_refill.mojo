@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Seg(Movable):
    var lo: Pair
    var hi: Pair


def main():
    var s: Seg
    s.lo = Pair(1, 2)
    var k = s.lo^
    s.lo = Pair(3, 4)
    var m = s.lo^
    print(k.x, m.x)
    s = Seg(Pair(5, 6), Pair(7, 8))
    print(s.hi.y)
