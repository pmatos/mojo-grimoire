def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def first_of(ref xs: Array[List[Int], 2]) -> ref [xs] List[Int]:
    return xs[0]


def main():
    var xs: List[Int] = [1, 2]
    print(len(first(xs)))
    print(len(first(first(xs))))
    ref r = first(first(xs))
    print(len(r))
    var ys: Array[List[Int], 2] = [[1], [2, 3]]
    print(len(first_of(ys)))
