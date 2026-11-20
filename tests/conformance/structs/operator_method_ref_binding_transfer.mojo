struct A(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __add__(mut self, o: B) -> Int:
        self.n += 1
        return 1


struct B(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __radd__(self, o: A) -> Int:
        return 2


struct W(Movable):
    var inner: A

    def __init__(out self, n: Int):
        self.inner = A(n)


def idr(ref a: A) -> ref [a] A:
    return a


def main():
    var w = W(1)
    var b = B(2)
    ref r = w^.inner
    print(r + b)
    ref s = r
    print(s + b)
    ref t = idr(r)
    print(t + b)
    print(w^.inner + b)
    print(w.inner.n)
