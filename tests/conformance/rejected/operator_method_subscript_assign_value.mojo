@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i


def main():
    var w = W(1)
    w[0] = 5
    print(w.n)
