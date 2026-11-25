def f(k: Int) -> Int:
    print("f", k)
    return k


def takel(v: List[Int]) -> Int:
    return len(v)


def takell(v: List[List[Int]]) -> Int:
    return len(v)


def takea(v: Array[Int, 2]) -> Int:
    return v[0] + v[1]


def takeaa(v: Array[Array[Int, 2], 2]) -> Int:
    return v[1][0]


def takei(v: Int) -> Int:
    return v


def rl(k: Int) -> List[Int]:
    return [k, f(k)]


def rll(k: Int) -> List[List[Int]]:
    return [[k], [k, k], []]


def ra(k: Int) -> Array[Int, 2]:
    return [f(k), k]


def rb() -> Array[Bool, 2]:
    return [True, 1 < 2]


def ri() -> Int:
    return [3]


def main():
    var x = 1
    var a = [1, 2]
    var xs: List[Int] = [1, 2]
    var ys: List[List[Int]] = [[1], [2]]
    a = [[], xs[0]]
    print(a[0])
    var v: List[Int] = [a]
    print(len(v))
    print(takea([]))
    print(x, len(xs), len(ys), a[0])
