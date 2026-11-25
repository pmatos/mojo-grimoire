def grow(mut xs: List[Int]) -> Int:
    xs.append(9)
    return 5


def main():
    var xs: List[Int] = [1, 2]
    xs[2] = grow(xs)
    print(xs[0], xs[1], xs[2])
