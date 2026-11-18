@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Seg(Movable):
    var lo: Pair
    var hi: Pair


def main():
    var c = True
    var s: Seg
    if c:
        s = Seg(Pair(1, 2), Pair(3, 4))
    else:
        s.lo = Pair(5, 6)
    var k = s.lo^
    print(k.x)
