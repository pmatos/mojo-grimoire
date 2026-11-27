@fieldwise_init
struct M(Movable):
    var f: Bool

    def __bool__(self) -> Bool:
        return self.f


def idM(var x: M) -> M:
    return x^


def main():
    var m = M(True)
    var a = [1, 2]
    print(a[idM(m)])
