struct S(Movable):
    var n: Int

    def m(self):
        var y: Int
        print(y)

    def __init__(out self):
        self.n = 1
        var xs: List[Int] = [1, 2]
        ref r = xs[0]
        xs.append(3)
        print(r)


def main():
    var s = S()
    s.m()
