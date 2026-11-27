@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0


@fieldwise_init
struct V(ImplicitlyCopyable):
    var n: Int


def f(a: A, v: V):
    print(v and a)


def main():
    print(1)
