struct A(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __add__(mut self, o: B) -> Int:
        return 1


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

    def __call__(self, x: A) -> ref [x] A:
        return x


def c(mut x: A) -> ref [x] A:
    return x


def f(c: C):
    var x = A(3)
    var b = B(2)
    ref r = c(x)
    print(r + b)


def main():
    f(C(0))
