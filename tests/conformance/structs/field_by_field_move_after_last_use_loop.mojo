@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Seg(Movable):
    var lo: Pair
    var hi: Pair


def main():
    var i = 0
    var s: Seg
    s.hi = Pair(0, 7)
    while i < 2:
        s.lo = Pair(i, i)
        var m = s.lo^
        print(m.x)
        i = i + 1
    print("end")
