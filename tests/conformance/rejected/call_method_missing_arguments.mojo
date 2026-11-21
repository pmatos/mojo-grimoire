@fieldwise_init
struct T(Copyable):
    var n: Int

    def __call__(self, a: Int, b: Int) -> Int:
        return self.n + a + b


def main():
    var t = T(1)
    print(t())
