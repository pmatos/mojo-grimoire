@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int


@fieldwise_init
struct MO(Movable):
    var g: Bool


def tmo(var a: MO) -> Int:
    return 1


def main():
    var mo1 = MO(True)
    var la: List[A] = [A(1)]
    ref r = la[tmo(mo1) - mo1.copy()]
    print(r.n)
