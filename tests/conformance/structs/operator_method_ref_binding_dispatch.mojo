@fieldwise_init
struct A(Copyable):
    var n: Int

    def __add__(mut self, b: B) -> Int:
        print("add")
        self.n += 10
        return self.n + b.n


@fieldwise_init
struct B(Copyable):
    var n: Int

    def __radd__(self, a: A) -> Int:
        print("radd")
        return self.n + a.n


def pick(a: A, mut c: A) -> ref[c] A:
    return c


def use(x: A):
    var y = A(1)
    ref r = pick(x, y)
    print(r + B(2))
    print(y.n)


def get(a: A) -> ref[a] A:
    return a


def main():
    use(A(5))
    var a = A(1)
    ref r = get(a)
    print(r + B(2))
