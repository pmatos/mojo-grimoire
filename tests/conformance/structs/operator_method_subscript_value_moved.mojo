@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i


def take(var w: W) -> Int:
    return w.n


def main():
    var w = W(1)
    print(w[0], take(w^))
