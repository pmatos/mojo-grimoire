def f():
    var y: Int
    print(y)


struct S(Movable):
    var n: Int

    def __init__(out self):
        self.n = 1

    def m(self):
        var xs: List[Int] = [1, 2]
        ref r = xs[0]
        xs.append(3)
        print(r)


def main():
    f()
