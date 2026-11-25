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
    var ab = [True, False]
    var xs: List[Int] = [1, 2]
    var ws: List[Int] = [2]
    var ys: List[List[Int]] = [[1], [2]]
    t = [y, -y] < [[len(xs), 1], [1, ys[1][0]]]
    print(t)
    print([ys != [[]], t] == ab)
    print(fb([[[3, 0]]] >= ys) and fb(t))
    print(len(ws), aa[1][0])
