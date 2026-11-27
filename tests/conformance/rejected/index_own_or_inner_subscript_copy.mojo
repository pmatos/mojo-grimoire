@fieldwise_init
struct M(Movable):
    var f: Bool

    def __bool__(self) -> Bool:
        return self.f


def idM(var x: M) -> M:
    return x^


def main():
    var m = M(True)
    var xs: List[Int] = [1]
    var z = 0
    z = xs[m or M(xs[1] > 0)]
    print(z)
