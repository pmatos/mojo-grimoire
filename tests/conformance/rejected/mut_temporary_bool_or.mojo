@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0


def pick(a0: A) -> A:
    return A(1) or a0


def main():
    var r = pick(A(0))
    print(r.n)
