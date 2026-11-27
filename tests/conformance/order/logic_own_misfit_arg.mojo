struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self) -> Bool:
        return self.n != 0


def pz(x: T) -> Int:
    return 0

def idT(var x: T) -> T:
    return x^


def f(t1: T):
    var lT: List[T] = [T(0), T(1)]
    var bv = False
    print(pz(idT((lT[0] or bv)) or t1))


def main():
    print(1)
