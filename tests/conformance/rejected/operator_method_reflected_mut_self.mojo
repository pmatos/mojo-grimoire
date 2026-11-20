struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __radd__(mut self, k: Int) -> Int:
        self.n += k
        return self.n


def g(t: T):
    print(5 + t)


def main():
    g(T(3))
