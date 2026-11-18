@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Seg(Movable):
    var lo: Pair
    var hi: Pair


def swap_lo(mut s: Seg):
    var old = s.lo^
    s.lo.x = old.y
    s.lo.y = old.x


def main():
    var s = Seg(Pair(1, 2), Pair(3, 4))
    swap_lo(s)
    print(s.lo.x)
