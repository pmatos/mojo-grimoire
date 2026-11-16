def bump(mut xs: List[Int]) -> Int:
    xs.append(7)
    return 5


def main():
    var xs: List[Int] = [1, 2]
    xs[0] = bump(xs)
    print(xs[0], len(xs))
