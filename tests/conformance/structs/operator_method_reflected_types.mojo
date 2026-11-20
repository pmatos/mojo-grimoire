@fieldwise_init
struct U(Copyable):
    var n: Int


@fieldwise_init
struct T(Copyable):
    var n: Int

    def __radd__(self, o: U) -> Int:
        return o.n + self.n

    def __rmul__(self, b: Bool) -> Int:
        return 7

    def __rsub__(self, xs: List[Int]) -> Int:
        return len(xs) - self.n


def main():
    var u = U(1)
    var t = T(2)
    var xs: List[Int] = [4, 5]
    print(u + t, True * t, xs - t)
