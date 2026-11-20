@fieldwise_init
struct R(Copyable):
    var n: Int

    def __call__(self, k: Int) -> List[Int]:
        return [self.n, k]


@fieldwise_init
struct L(Copyable):
    var n: Int

    def __call__(self, xs: List[Int]) -> Int:
        return self.n


@fieldwise_init
struct U(Copyable):
    var n: Int


@fieldwise_init
struct S(Copyable):
    var n: Int

    def __call__(self, k: Int) -> Int:
        return self.n * k


def main():
    var range = R(7)
    var xs = List[Int](range(3))
    var len = L(9)
    var U = S(4)
    print(xs, len(xs), U(2))
