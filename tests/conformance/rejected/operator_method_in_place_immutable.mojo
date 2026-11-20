@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(self, k: Int):
        print(self.n + k)


def g(t: T):
    t += 1


def main():
    g(T(1))
