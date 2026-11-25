def grow(mut xs: List[Int]) -> Int:
    xs.append(9)
    return 0


def main():
    var ys: List[Int] = [0, 1]
    var xs: List[Int] = [1, 2]
    ref e = ys[0]
    xs[grow(ys)] = e
    print(xs[0], xs[1])
