@fieldwise_init
struct T(Copyable):
    var n: Int

    def __eq__(self, o: Self) -> Bool:
        return self.n == o.n


def main():
    var t = T(1)
    var u = T(2)
    print(t != u)
