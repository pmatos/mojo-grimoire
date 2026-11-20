@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(self, k: Int) -> Int:
        return self.n + k

    def __radd__(self, k: Int) -> Int:
        print("radd", self.n, k)
        return self.n * 100 + k

    def __rsub__(self, k: Int) -> Int:
        return k - self.n

    def __rmul__(self, k: Int) -> Int:
        return k * self.n

    def __rfloordiv__(self, k: Int) -> Int:
        return k // self.n

    def __rmod__(self, k: Int) -> Int:
        return k % self.n

    def __deinit__(deinit self):
        print("del T", self.n)


def mk(k: Int) -> T:
    print("mk", k)
    return T(k)


def pr(k: Int) -> Int:
    print("pr", k)
    return k


def main():
    var t = T(3)
    var k = 10
    print(t + 2, 1 + t)
    print(k - t, k * t, k // t, k % t)
    print(pr(5) + mk(2))
    print("end")
