@fieldwise_init
struct T(Copyable):
    var n: Int

    def __call__(mut self, a: Int):
        self.n += a


def g(t: T):
    t(2)


def main():
    g(T(1))
