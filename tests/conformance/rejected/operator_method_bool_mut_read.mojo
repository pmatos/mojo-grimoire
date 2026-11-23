struct C(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Bool:
        self.n -= 1
        return self.n > 0


def pick(a: C, b: C) -> C:
    return a and b


def main():
    var a = C(2)
    var b = C(3)
    var r = pick(a, b)
    print(r.n, a.n, b.n)
