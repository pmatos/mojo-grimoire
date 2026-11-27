struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0


def pz(x: T) -> Int:
    return 0

def eatT(var x: T) -> T:
    return x^

def same(ref x: T) -> ref [x] T:
    return x


def main():
    var t0 = T(1)
    ref rr = same(t0)
    print(pz(same(t0) or eatT(rr^)))
