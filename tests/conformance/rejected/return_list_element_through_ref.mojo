def second(mut xs: List[Int]) -> ref [xs] Int:
    ref r = xs[1]
    return r


def main():
    var xs: List[Int] = [1, 2]
    print(second(xs))
