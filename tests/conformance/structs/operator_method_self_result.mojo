@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(self, o: Self) -> Self:
        return T(self.n + o.n)


def main():
    var t = T(5)
    var u = t + t + t
    print(u.n)
