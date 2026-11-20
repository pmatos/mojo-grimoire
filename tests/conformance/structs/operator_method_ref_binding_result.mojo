struct A(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __add__(mut self, o: B) -> Int:
        self.n += 1
        return 1

    def __sub__(mut self, k: Int) -> ref [self] A:
        return self

    def __neg__(mut self) -> ref [self] A:
        return self

    def __mod__(ref self, k: Int) -> ref [self] A:
        return self


struct B(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __radd__(self, o: A) -> Int:
        return 2


struct C(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __call__(self, mut x: A) -> ref [x] A:
        return x


def main():
    var c = C(0)
    var a = A(3)
    var b = B(2)
    ref r = c(a)
    print(r + b)
    ref s = a - 1
    print(s + b)
    ref t = -a
    print(t + b)
    ref u = a % 2
    print(u + b)
    print(a.n)
