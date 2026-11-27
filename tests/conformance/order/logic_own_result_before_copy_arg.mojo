struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Int:
        return self.n


def pz(x: T) -> Int:
    return 0


def main():
    var t1 = T(1)
    var t2 = T(0)
    print(pz(t1 or t2))
