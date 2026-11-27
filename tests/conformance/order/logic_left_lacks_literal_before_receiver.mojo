@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0


def f(a: A):
    var r = [1, 2] or a


def main():
    print(1)
