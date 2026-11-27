struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Bool:
        return self.n != 0


def pz(x: T) -> Int:
    return 0


def f(t1: T, t2: T):
    print(pz(t1 or t2))


def main():
    print(1)
