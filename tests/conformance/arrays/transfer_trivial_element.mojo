@fieldwise_init
struct Holder(Movable):
    var xs: Array[Int, 2]


def main():
    var a = [5, 6]
    var c = a[1]^
    print(c, a[1])
    var bs = [False, True]
    var b = bs[0]^
    print(b, bs[0])
    var h = Holder([7, 8])
    var n = h.xs[0]^
    print(n, h.xs[0])
