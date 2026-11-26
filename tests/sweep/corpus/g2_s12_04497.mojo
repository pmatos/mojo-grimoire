def f(k: Int) -> Int:
    print("f", k)
    return k


def fb(b: Bool) -> Bool:
    print("fb", b)
    return b


def g() -> List[Int]:
    return [1, 2]


def ga() -> Array[Int, 2]:
    return [1, 2]


def gl() -> List[List[Int]]:
    return [[1], [2]]


def tb(b: Bool) -> Bool:
    return b


def main():
    var y = 2
    var t = True
    var aa = [[1, 2], [3, 4]]
    var xs: List[Int] = [1, 2]
    var ws: List[Int] = [2]
    var ys: List[List[Int]] = [[1], [2]]
    var xa: List[Array[Int, 2]] = [[1, 2]]
    t = xa != [[[3, xs[0]], [ys[1][0], y]]]
    print(t)
    print([1] == True)
    print(fb(xa == [[[0, len(xs)]]]) and fb(t))
    print(len(ws), aa[1][0])
