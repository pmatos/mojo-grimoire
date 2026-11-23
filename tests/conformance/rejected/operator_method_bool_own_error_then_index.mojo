struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n


struct U(ImplicitlyCopyable):
    var f: Bool

    def __init__(out self, f: Bool):
        self.f = f

    def __bool__(self) -> Int:
        return 1


def bi(a: Int) -> Int:
    return a


def main():
    var u = U(True)
    var u2 = U(False)
    var lt: List[T] = [T(1), T(2)]
    lt[bi(u)] = (u or u2)
