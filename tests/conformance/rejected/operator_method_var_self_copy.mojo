@fieldwise_init
struct T(Copyable):
    var n: Int

    def __add__(var self, k: Int) -> Int:
        return self.n + k


def main():
    var t = T(1)
    print(t + 1)
