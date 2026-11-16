def look(xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def n(mut ys: List[Int]) -> Int:
    return len(ys)


def main():
    var xs: List[Int] = [1, 2]
    print(n(look(xs)))
