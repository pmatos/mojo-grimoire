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
    var bs: List[Bool] = [True, False]
    if aa[1] != [3, 2]:
        print("yes")
    else:
        print("no")
    var r22 = xs.copy() != [[y, 2]]
    print(t)
    print(not ([[False, not t]] == bs))
    print(t)
