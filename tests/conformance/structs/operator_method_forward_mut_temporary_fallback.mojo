@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(self, mut o: Self) -> Int:
        return 1

    def __radd__(self, o: Self) -> Int:
        print("radd")
        return 2


def main():
    var t = T(1)
    print(t + T(2))
