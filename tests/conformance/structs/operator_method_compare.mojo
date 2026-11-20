@fieldwise_init
struct T(Copyable):
    var n: Int

    def __lt__(self, o: Self) -> Bool:
        return self.n < o.n

    def __eq__(self, o: Self) -> Bool:
        return self.n == o.n

    def __le__(self, o: Self) -> Int:
        return 42


def main():
    var t = T(1)
    var u = T(2)
    print(t < u, t == u, u > t, t <= u, u >= t)
