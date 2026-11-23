struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0


def main():
    var t = T(1)
    var t2 = T(0)
    var r = (((((((((((((((((((((((((((((((((((((((t or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2) and t2) or t2)
    print(r.n)
