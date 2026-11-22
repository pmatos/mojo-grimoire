struct M(Movable):
    var f: Bool

    def __init__(out self, f: Bool):
        self.f = f

    def __bool__(self) -> Bool:
        return self.f


def f2(a: Int, b: Bool) -> Int:
    return a


def main():
    var m = M(True)
    var m2 = M(False)
    var zi = f2(not m, m or m2)
    print(zi)
