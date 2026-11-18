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
    while i < 2:
        s = Seg(Pair(i, i), Pair(i, i))
        var k = s^
        s.lo = Pair(i + 5, i)
        print(k.lo.x)
        i = i + 1
    print("end")
