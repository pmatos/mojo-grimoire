struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0


struct H(Movable):
    var t: T

    def __init__(out self, var t: T):
        self.t = t^

def pz(x: T) -> Int:
    return 0


def f(t2: T):
    var lT: List[T] = [T(0), T(1)]
    var hl: List[H] = [H(T(0)), H(T(1))]
    print(lT[pz((hl[0].t and t2^))].n)


def main():
    print(1)
