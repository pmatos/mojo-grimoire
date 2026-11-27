struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Bool:
        return self.n != 0


def pz(x: T) -> Int:
    return 0


def main():
    var t1 = T(1)
    var t2 = T(0)
    print(pz(t1 or t2))
