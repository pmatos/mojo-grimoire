@fieldwise_init
struct S(Copyable):
    var n: Int

    def __call__(self, k: Int) -> Int:
        return self.n + k


@fieldwise_init
struct P(Copyable):
    var n: Int

    def __call__(self, k: Int):
        print(self.n + k)


def f(k: Int) -> Int:
    return 1


def use(len: S, xs: List[Int]):
    print(len(5))


def main():
    var f = S(7)
    print(f(1))
    var print = P(10)
    print(1)
    use(S(3), [1])
