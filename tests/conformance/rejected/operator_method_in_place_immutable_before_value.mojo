@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(mut self, k: Int):
        self.n += k


def g(t: T):
    t += nope


def main():
    g(T(1))
