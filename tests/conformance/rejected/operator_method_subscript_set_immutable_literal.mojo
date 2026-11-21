@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v


def use(w: W):
    w[0] = [1, 2]


def main():
    use(W(1))
