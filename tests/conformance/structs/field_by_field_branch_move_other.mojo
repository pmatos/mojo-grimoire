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
        s.lo = Pair(1, 2)
        var k = s.lo^
        print(k.x)
    else:
        s.hi = Pair(3, 4)
        print(s.hi.x)
    print("end")
