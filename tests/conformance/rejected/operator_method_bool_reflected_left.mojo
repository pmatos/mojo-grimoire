struct T(ImplicitlyCopyable):
    var n: Int
    var f: Bool

    def __init__(out self, n: Int, f: Bool):
        self.n = n
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


struct W(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __radd__(self, o: T) -> Int:
        return o.n + self.n


def main():
    var x = T(1, False)
    var y = T(2, True)
    var ww = W(4)
    var c = x^
    var z: Bool = (x or y) + ww
    print(z, c.n)
