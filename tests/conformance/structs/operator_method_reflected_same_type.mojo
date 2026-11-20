@fieldwise_init
struct T(Copyable):
    var n: Int

    def __radd__(self, o: Self) -> Int:
        return 7


def main():
    var t = T(1)
    var u = T(2)
    print(t + u)
