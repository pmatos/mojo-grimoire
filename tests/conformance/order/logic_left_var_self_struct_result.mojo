@fieldwise_init
struct W(ImplicitlyCopyable):
    var n: Int


@fieldwise_init
struct B(Copyable):
    var n: Int

    def __bool__(var self) -> W:
        return W(self.n)


def mkB() -> B:
    return B(1)


def f(c: Bool):
    var r = B(1) or c


def main():
    print(1)
