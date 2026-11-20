struct W(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(mut self, i: Int) -> Int:
        print("get", self.n, i)
        self.n += 10
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v


@fieldwise_init
struct Q(Copyable):
    var w: W
    var k: Int


def main():
    var x = W(1)
    var q = Q(x, x[0])
    print(q.w.n, q.k, x.n)
