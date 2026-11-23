struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0

    def __add__(self, o: Self) -> Self:
        return T(self.n + o.n)


def main():
    var a = T(0)
    var b = T(2)
    var r = ((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((a + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a) + b) or a)
    print(r.n)
