def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def n(a: List[Int], mut b: List[Int]) -> Int:
    return len(a)


def main():
    var xs: List[Int] = [1, 2]
    print(n(first(xs), xs))
