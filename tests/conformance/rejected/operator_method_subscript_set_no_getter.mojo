@fieldwise_init
struct W(Copyable):
    var n: Int

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v


def main():
    var w = W(1)
    w[0] = W(2)
    print(w.n)
