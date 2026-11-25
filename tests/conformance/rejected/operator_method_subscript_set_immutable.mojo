@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v


def g(w: W):
    w[0] = 1


def main():
    g(W(1))
