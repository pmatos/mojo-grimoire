@fieldwise_init
struct T(Movable):
    var n: Int

    def __add__(self, k: Int) -> Int:
        return self.n + k


def main():
    var t = T(1)
    print(t + 1)
    print(t.n)
