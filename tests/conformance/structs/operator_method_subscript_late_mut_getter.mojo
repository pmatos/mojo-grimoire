struct W(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __getitem__(mut self, i: Int) -> Int:
        print("get", self.n, i)
        self.n += 10
        return self.n + i

    def __setitem__(mut self, i: Int, v: Int):
        self.n = v


def f(a: Int, b: Int) -> Int:
    print("f", a, b)
    return a + b


def main():
    var x = W(2)
    print(x.n, x[0])
    print(f(x.n, x[0]))
    print(x.n + x[0])
    var xs = [x.n, x[0]]
    print(xs[0], xs[1])
