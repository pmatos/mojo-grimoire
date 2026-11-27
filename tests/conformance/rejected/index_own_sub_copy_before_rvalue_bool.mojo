@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int


@fieldwise_init
struct MO(Movable):
    var g: Bool


def tmo(var a: MO) -> Int:
    return 1


@fieldwise_init
struct MS(ImplicitlyCopyable):
    var g: Bool

    def __bool__(mut self) -> Bool:
        return self.g


def main():
    var ms1 = MS(True)
    var mo1 = MO(True)
    var la: List[A] = [A(1)]
    ref r = la[tmo(mo1) - (not ms1^)]
    print(r.n)
