@fieldwise_init
struct T(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i


def main():
    var t = T(5)
    print(t[True])
