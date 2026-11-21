def pick(ref xs: List[Int]) -> ref [xs] List[Int]:
    return xs


def bump(mut xs: List[Int]) -> List[Int]:
    xs.append(9)
    return [1, 9]


def main():
    var xs: List[Int] = [1]
    var ys: List[Int] = [1]
    print(pick(xs) == ys, xs == pick(ys))
    print(xs == bump(xs))
