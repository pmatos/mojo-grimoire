@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(self, k: Int):
        print(self.n + k)


def main():
    var t = T(1)
    t += 2
    print(t.n)
