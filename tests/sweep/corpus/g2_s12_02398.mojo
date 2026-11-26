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
    var y = 2
    var a = [1, 2]
    var c = [2, 1]
    var aa = [[1, 2], [3, 4]]
    var a11 = [[1]]
    var ws: List[Int] = [2]
    var bs: List[Bool] = [True, False]
    print(([[[a[1], a[1], 3]]] != gl()) != (bs != [tb(False), True]))
    print(tb(a11 >= [[3], x + 1]), x)
    if [0, y] >= c:
        print("yes")
    else:
        print("no")
    print(len(ws), aa[1][0])
