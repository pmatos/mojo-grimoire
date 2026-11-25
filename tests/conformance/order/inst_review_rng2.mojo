struct P(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x


def g(var p: P, k: Int) -> Int:
    return k


def main():
    var xs: List[Int] = [1, 2]
    var p = P(1)
    print(len(List[Int](range(g(p^, xs[-1]), p.x))))
