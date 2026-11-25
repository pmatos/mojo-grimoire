struct M(Movable):
    var f: Bool

    def __init__(out self, f: Bool):
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


def tmo(var m: M) -> Int:
    return 0


def b3(b: Bool, k: Int, kb: Bool) -> Int:
    return k


def main():
    var mo1 = M(True)
    var a1 = True
    var kb = False
    var k = 1
    var xs: List[Int] = [1, 2]
    xs[tmo(mo1^)] = b3(mo1 and a1, k, kb)
    print(xs[0])
