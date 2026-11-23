struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0


def main():
    var t = T(1)
    var t2 = T(0)
    var b: Bool = t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t or t2 or t
    print(b)
