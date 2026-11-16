def first(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def shrink(mut ys: List[List[Int]]) -> Int:
    var t = ys.pop()
    return 0


def main():
    var ls: List[List[Int]] = [[1, 2]]
    print(first(ls[0]), shrink(ls))
