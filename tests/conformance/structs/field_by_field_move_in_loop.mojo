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
    var p: Pair
    var s: Seg
    while i < 2:
        p = Pair(i, i)
        var k = p^
        s.lo = Pair(i + 5, i)
        var m = s.lo^
        print(k.x, m.x)
        i = i + 1
    print("end")
