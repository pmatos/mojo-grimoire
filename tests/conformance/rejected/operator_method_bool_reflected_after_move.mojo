struct T(ImplicitlyCopyable):
    var n: Int
    var f: Bool

    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f

    def __bool__(self) -> Bool:
        return self.f

    def __lt__(self, o: T) -> Bool:
        return self.n < o.n


def main():
    var x = T(1, False)
    var y = T(2, True)
    var w = T(3, False)
    var c = x^
    var z: Int = w > (x or y)
    print(z, c.n)
