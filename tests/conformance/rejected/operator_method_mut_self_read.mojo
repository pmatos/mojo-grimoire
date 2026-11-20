@fieldwise_init
struct T(Copyable):
    var n: Int

    def __neg__(mut self) -> Int:
        return -self.n


def g(t: T):
    print(-t)


def main():
    g(T(1))
