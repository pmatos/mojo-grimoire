@fieldwise_init
struct M(Movable):
    var f: Bool

    def __bool__(self) -> Bool:
        return self.f


def idM(var x: M) -> M:
    return x^


def main():
    var xs: List[Int] = [1, 2, 3]
    print(xs[idM(M(True))])
