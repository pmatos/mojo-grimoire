def same(ref x: Int) -> ref [x] Int:
    return x


def first(ref xs: Array[Int, 2]) -> ref [xs] Int:
    return xs[0]


def second(mut xs: Array[Int, 2]) -> ref [xs] Int:
    ref r = xs[1]
    return r


def via(ref xs: Array[Int, 2]) -> ref [xs] Int:
    return same(xs[1])


def corner(ref g: Array[Array[Int, 2], 2]) -> ref [g] Int:
    return g[1][0]


def pick(ref xs: List[Int], ref ys: Array[Int, 2]) -> ref [xs, ys] Int:
    return ys[1]


def main():
    var xs: Array[Int, 2] = [1, 2]
    ref a = first(xs)
    a = 10
    ref b = second(xs)
    b += 5
    print(xs[0], xs[1], via(xs))
    var g: Array[Array[Int, 2], 2] = [[1, 2], [3, 4]]
    ref c = corner(g)
    c = 30
    print(g[1][0], g[1][1])
    var l: List[Int] = [7]
    print(pick(l, xs), len(l))
