@fieldwise_init
struct T(Copyable):
    var n: Int

    def __sub__(self, k: Int) -> Int:
        return self.n - k

    def __mul__(self, k: Int) -> Int:
        return self.n * k

    def __floordiv__(self, k: Int) -> Int:
        return self.n // k

    def __mod__(self, k: Int) -> Int:
        return self.n % k


def main():
    var t = T(7)
    print(t - 1, t * 2, t // 2, t % 4)
