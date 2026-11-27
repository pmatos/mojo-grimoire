@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(mut self) -> Int:
        return self.n


def f(a: A):
    print(a or True)


def main():
    print(1)
