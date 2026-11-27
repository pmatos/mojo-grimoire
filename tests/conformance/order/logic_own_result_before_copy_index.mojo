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
    var lT: List[T] = [T(0), T(1)]
    print(lT[pz((lT[0] and t1))].n)
