def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def n(mut ys: List[Int]) -> Int:
    return len(ys)


def g(xs: List[Int]) -> Int:
    return n(first(xs))


def main():
    var xs: List[Int] = [1, 2]
    print(g(xs))
