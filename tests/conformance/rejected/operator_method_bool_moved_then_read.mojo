struct T(ImplicitlyCopyable):
    var n: Int
    var f: Bool

    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


def main():
    var x = T(1, True)
    var b = False
    b = (x^ or T(3, True)) and x.f
    print(b)
