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


def gi(var k: Int, j: Int) -> Int:
    print("gi", k, j)
    return k + j


def main():
    var x = W(1)
    print(gi(x.n, x[0]))
