@fieldwise_init
struct B(Copyable):
    var n: Int

    def __radd__(self, a: A) -> Int:
        print("radd")
        return self.n + a.n


@fieldwise_init
struct A(Copyable):
    var n: Int

    def __add__(mut self, b: B) -> Int:
        print("add")
        return self.n + b.n


def use(a: A, b: B) -> Int:
    return a + b


def main():
    print(use(A(1), B(2)))
