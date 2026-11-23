struct T(ImplicitlyCopyable):
    var n: Int
    var f: Bool

    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


def bi(a: Int) -> Int:
    return a


def main():
    var y = T(2, True)
    var w = T(3, False)
    print(y or w, bi(w))
