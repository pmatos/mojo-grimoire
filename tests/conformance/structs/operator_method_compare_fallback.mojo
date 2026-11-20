@fieldwise_init
struct T(Copyable):
    var n: Int

    def __gt__(self, k: Int) -> Bool:
        return True

    def __lt__(self, o: Self) -> Bool:
        return self.n < o.n

    def __eq__(self, k: Int) -> Bool:
        return self.n == k

    def __ne__(self, k: Int) -> Bool:
        return self.n != k


def main():
    var t = T(2)
    var u = T(3)
    var k = 2
    print(u > t, t > 1, 1 < t, k == t, k != t)
