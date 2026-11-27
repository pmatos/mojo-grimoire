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
    var hl: List[H] = [H(T(0)), H(T(1))]
    print(pz(hl[0].t or t2^))


def main():
    print(1)
