@fieldwise_init
struct S(Copyable):
    var n: Int

    def __call__(self) -> Int:
        return self.n


def main():
    var f: S
    print(f())
