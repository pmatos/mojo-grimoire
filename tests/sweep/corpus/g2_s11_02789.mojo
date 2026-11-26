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
    var t = True
    print(not (gl() != [[[f(1)], [f(1), 2]]]))
    print([f(1)] + 2)
    print(len([]))
    print(t)
