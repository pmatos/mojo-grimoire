def pick(ref a: Array[Int, 2]) -> ref [a] Array[Int, 2]:
    return a


def lt(a: Array[Int, 2], b: Array[Int, 2]) -> Bool:
    return a < b


@fieldwise_init
struct H(Movable):
    var a: Array[Int, 2]


def main():
    var a = [1, 2]
    var b = [1, 3]
    print(pick(a) < pick(b), pick(a) == b, lt(a, b), lt([2, 0], a))
    var h = H([1, 2])
    var g = H([1, 2])
    print(h.a == g.a, h.a < g.a)
    var xs: List[Array[Int, 1]] = [[1], [2]]
    print(xs[0] < xs[1], xs[1] == [2])
