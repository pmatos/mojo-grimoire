@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(self, o: Self) -> Self:
        return T(self.n + o.n)


def main():
    var t = T(1)
    var u = T(2)
    t += u
    print(t.n)
