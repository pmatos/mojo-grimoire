@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(mut self, o: Self):
        self.n += o.n


def main():
    var t = T(1)
    t += t
    print(t.n)
