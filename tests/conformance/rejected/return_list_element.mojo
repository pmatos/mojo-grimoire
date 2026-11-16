def first(ref xs: List[Int]) -> ref [xs] Int:
    return xs[0]


def main():
    var xs: List[Int] = [1, 2]
    print(first(xs))
