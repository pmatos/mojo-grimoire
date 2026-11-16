@fieldwise_init
struct Flags(Movable):
    var on: Bool
    var n: Int


def show(x: Int):
    var y = x^
    print("show", x, y)


def main():
    var x = 1
    var y = x^
    var b = True
    var c = b^
    print(x, y, b, c)
    var f = Flags(False, 2)
    var n = f.n^
    print(f.on, f.n, n)
    show(x^)
    ref r = x
    var z = r^
    var i = 0
    while i < 3:
        i += z^
    print(x, z, i)
