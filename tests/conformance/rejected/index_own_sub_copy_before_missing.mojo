@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int


@fieldwise_init
struct MO(Movable):
    var g: Bool


def tmo(var a: MO) -> Int:
    return 1


@fieldwise_init
struct I(ImplicitlyCopyable):
    var g: Bool


def main():
    var i1 = True
    var i2 = I(False)
    var mo1 = MO(True)
    var la: List[A] = [A(1)]
    ref r = la[tmo(mo1) - (i1 or i2)]
    print(r.n)
