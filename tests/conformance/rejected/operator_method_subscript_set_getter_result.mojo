@fieldwise_init
struct W(Copyable):
    var n: Int

    def __getitem__(self, i: Int) -> Int:
        return self.n

    def __setitem__(mut self, i: Int, v: Bool):
        print("set", i, v)


def main():
    var w = W(1)
    w[1] = True
    print(w.n)
