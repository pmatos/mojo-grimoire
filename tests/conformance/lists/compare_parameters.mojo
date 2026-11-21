def eq(xs: List[Int], ys: List[Int]) -> Bool:
    return xs == ys


def main():
    var xs: List[Int] = [1]
    print(eq(xs, [1]), eq([2], xs))
