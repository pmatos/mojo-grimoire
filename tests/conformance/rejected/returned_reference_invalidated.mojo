def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def grow(mut ys: List[List[Int]]) -> Int:
    ys.append([7])
    return 0


def two(a: List[Int], b: Int) -> Int:
    return len(a) + b


def main():
    var xs: List[List[Int]] = [[1, 2]]
    print(two(first(xs[0]), grow(xs)))
