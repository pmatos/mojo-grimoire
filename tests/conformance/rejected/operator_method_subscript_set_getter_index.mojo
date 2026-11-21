@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n + i

    def __setitem__(mut self, b: Bool, v: Int):
        print("set", b, v)
        self.n = v


def main():
    var w = W(1)
    w[True] = 5
    print(w.n)
