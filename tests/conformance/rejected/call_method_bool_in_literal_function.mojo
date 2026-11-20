@fieldwise_init
struct C(Copyable):
    var n: Int

    def __call__(self, x: List[Int]) -> Bool:
        return True


def g(x: List[Int]) -> Int:
    return 1


def main():
    var g = C(1)
    var xs: List[Int] = [1]
    print(-[True, g(xs)])
