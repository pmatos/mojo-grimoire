@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(self, k: Int) -> Int:
        return self.n + k


def main():
    var t = T(5)
    print(t + True)
