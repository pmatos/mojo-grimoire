@fieldwise_init
struct S(Copyable):
    var n: Int

    def __call__(mut self, mut o: S):
        o.n += self.n


def main():
    var f = S(3)
    f(f)
