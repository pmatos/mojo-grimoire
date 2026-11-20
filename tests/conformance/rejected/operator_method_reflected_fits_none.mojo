@fieldwise_init
struct T(Copyable):
    var n: Int

    def __radd__(self, b: Bool) -> Int:
        return 7


def main():
    var t = T(2)
    print(1 + t)
