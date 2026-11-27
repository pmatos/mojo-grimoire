struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Int:
        return self.n


def pz(x: T) -> Int:
    return 0


def f(t1: T, t2: T):
    var lT: List[T] = [T(0), T(1)]
    print(lT[pz((t1 and t2))].n)


def main():
    print(1)
