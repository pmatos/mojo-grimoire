def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def n(mut a: List[Int], b: List[Int]) -> Int:
    return len(b)


def main():
    var xs: List[Int] = [1, 2]
    print(n(xs, first(xs)))
