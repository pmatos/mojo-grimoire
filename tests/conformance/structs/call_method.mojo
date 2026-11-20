@fieldwise_init
struct T(Copyable):
    var n: Int

    def __call__(self, k: Int) -> Int:
        return self.n + k


@fieldwise_init
struct C(Copyable):
    var n: Int

    def __call__(mut self):
        self.n += 1


def show(f: T):
    print(f(1))


def main():
    var t = T(7)
    print(t(2))
    show(t)
    var c = C(1)
    c()
    c()
    print(c.n)
