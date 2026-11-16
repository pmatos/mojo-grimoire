def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def take(var ys: List[Int]) -> Int:
    return len(ys)


def two(a: List[Int], b: Int) -> Int:
    return len(a) + b


def main():
    var xs: List[Int] = [1, 2]
    print(two(first(xs), take(xs^)))
