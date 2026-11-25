def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def n(var ys: List[Int]) -> Int:
    return len(ys)


def main():
    var xs: List[Int] = [1, 2]
    print(n(first(xs)))
