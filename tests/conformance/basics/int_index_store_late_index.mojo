def zero(mut i: Int) -> Int:
    i = 0
    return 6


def clr(mut ys: List[Int]) -> Int:
    ys = [5, 5, 5]
    return 6


def main():
    var k = 7
    var i = 1
    k[i] = zero(i)
    print(k, i)
    var xs: List[Int] = [1, 2]
    var ys: List[Int] = [0]
    xs[0][ys[0] - 1 + 1] = clr(ys)
    xs[ys[0] - 5][0] = 4
    print(xs, ys)
