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
    var t = True
    var a = [1, 2]
    var xs: List[Int] = [1, 2]
    var ys: List[List[Int]] = [[1], [2]]
    print(x == f(1))
    print(t and (gl() == [[[x + 1, x + 1]]]))
    _ = xs.pop()
    print(x, len(xs), a[0], len(ys))
