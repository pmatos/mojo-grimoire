@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(self, k: Int) -> Self:
        return Self(self.n + k)


def g(t: T):
    t += True


def main():
    g(T(1))
