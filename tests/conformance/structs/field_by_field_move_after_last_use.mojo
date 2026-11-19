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
    s.hi = Pair(0, 7)
    s.lo = Pair(0, 0)
    var m = s.lo^
    print(m.x)
    print("end")
