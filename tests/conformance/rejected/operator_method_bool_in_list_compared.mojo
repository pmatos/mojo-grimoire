struct T(ImplicitlyCopyable):
    var n: Int
    var f: Bool

    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


def main():
    var x = T(1, False)
    var y = T(2, True)
    var k = 1
    var c = x^
    print(c.n)
    print([x or y] == [k])
