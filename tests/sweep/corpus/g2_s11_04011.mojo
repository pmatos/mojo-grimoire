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
    var x = 1
    var a = [1, 2]
    var xs: List[Int] = [1, 2]
    var ys: List[List[Int]] = [[1], [2]]
    var bs: List[Bool] = [True, False]
    print(x == [1, 2])
    print(tb([[tb(False), False]] != bs), x)
    bs[0] = False
    print(x, len(xs), a[0], len(ys))
