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
    s.lo = Pair(1, 2)
    while c:
        s.lo.x = 3
        c = False
    var k = s.lo^
    print(k.x)
