@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(mut self, k: Int):
        self.n += k

    def __isub__(mut self, k: Int):
        self.n -= k

    def __imul__(mut self, o: Self):
        self.n *= o.n


def grow(mut t: T):
    t += 10


def main():
    var t = T(1)
    t += 4
    t -= 2
    t *= T(3)
    grow(t)
    print(t.n)
