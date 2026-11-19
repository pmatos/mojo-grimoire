@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Seg(Movable):
    var lo: Pair
    var hi: Pair


def main():
    var p: Pair
    p.x = 1
    print(p.x)
    var s: Seg
    s.lo = Pair(2, 3)
    print(s.lo.y)
