@fieldwise_init
struct A(Copyable):
    var n: Int

    def __add__(mut self, b: B) -> Int:
        print("add")
        self.n += 10
        return self.n + b.n

    def me(mut self) -> ref[self] A:
        return self


@fieldwise_init
struct B(Copyable):
    var n: Int

    def __radd__(self, a: A) -> Int:
        print("radd")
        return self.n + a.n


def get(mut a: A) -> ref[a] A:
    return a


def main():
    var a = A(1)
    print(get(a) + B(2))
    print(a.n)
    var c = A(5)
    print(c.me() + B(2))
    print(c.n)
