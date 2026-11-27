@fieldwise_init
struct M(Movable):
    var f: Bool

    def __bool__(self) -> Bool:
        return self.f


def idM(var x: M) -> M:
    return x^


def main():
    var m = M(True)
    var m2 = M(False)
    var xs: List[Int] = [1]
    xs[m or m2] = 1
    print(xs[0])
