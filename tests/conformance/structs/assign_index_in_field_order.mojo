@fieldwise_init
struct P(Copyable, Movable):
    var xs: List[Int]


def show(k: Int) -> Int:
    print("eval", k)
    return k


def main():
    var p = P([1, 2, 3])
    p.xs[show(1)] = show(7)
    print(p.xs[0], p.xs[1])
