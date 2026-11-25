def reset(mut ys: List[Int]) -> Int:
    ys = [2, 2]
    return 6


def main():
    var xs: Array[Int, 3] = [7, 8, 9]
    var ys: List[Int] = [0, 1]
    xs[ys[0]] = reset(ys)
    print(xs[0], xs[2], ys[0])
