@fieldwise_init
struct T(Copyable):
    var n: Int

    def same(self, o: Self) -> Bool:
        return self.n == o.n

    def dup(self) -> Self:
        var r: Self = T(self.n + 1)
        return r^

    def all(self, ts: List[Self]) -> Int:
        return len(ts)


def main():
    var t = T(1)
    var u = t.dup()
    var ts: List[T] = []
    print(t.same(u), u.n, t.all(ts))
