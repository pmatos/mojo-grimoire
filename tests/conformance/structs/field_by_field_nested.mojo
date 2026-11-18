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
    s.lo.x = 5
    s.lo.y = 6
    print(s.lo.x, s.lo.y)
    s.lo = Pair(7, 8)
    s.hi.x = 9
    print(s.lo.x, s.hi.x)
