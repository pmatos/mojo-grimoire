struct T(ImplicitlyCopyable):
    var n: Int
    var f: Bool

    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


def t(k: Int) -> Bool:
    print("t", k)
    return True


def main():
    var x = T(1, False)
    var y = T(2, False)
    var n = 0
    y = (t(0) and x^) or x.f
    n = (t(1) and y^) or y.f
    print(y.n, n)
