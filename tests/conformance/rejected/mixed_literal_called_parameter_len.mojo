@fieldwise_init
struct C(Copyable):
    var a: Int

    def __call__(self, x: List[Int]) -> Int:
        return 1


def f(len: C):
    var xs: List[Int] = [1]
    print(-[True, len(xs)])


def main():
    f(C(1))
