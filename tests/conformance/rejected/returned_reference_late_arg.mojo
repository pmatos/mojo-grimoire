def pick(ref a: Int, ref b: Int, first: Bool) -> ref[a, b] Int:
    if first:
        return a
    return b


def grow(mut xs: List[Int]) -> Int:
    xs.append(3)
    return 0


def two(x: Int, y: Int) -> Int:
    return x + y


def main():
    var xs: List[Int] = [1, 2]
    var b = 5
    print(two(pick(xs[0], b, True), grow(xs)))
