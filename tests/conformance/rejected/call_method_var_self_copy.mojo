@fieldwise_init
struct S(Copyable):
    var n: Int

    def __call__(var self) -> Int:
        return self.n


def main():
    var f = S(1)
    print(f())
