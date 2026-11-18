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
    print(k.x, k.y)
