struct P(Copyable):
    var v: Int

    def __init__(out self, v: Int):
        self.v = v

    def __add__(self, o: P) -> Int:
        return self.v + o.v

    def __eq__(self, o: P) -> Bool:
        return self.v == o.v

    def lst(self) -> List[Int]:
        return [self.v]


struct H(Copyable):
    var xs: List[Int]
    var a: Array[Int, 2]

    def __init__(out self):
        self.xs = [1, 2]
        self.a = [1, 2]


def f(k: Int) -> Int:
    print("f", k)
    return k


def g() -> List[Int]:
    return [1, 2]


def ga() -> Array[Int, 2]:
    return [1, 2]


def tb(b: Bool) -> Bool:
    return b


def takel(v: List[Int]) -> Int:
    return len(v)


def takell(v: List[List[Int]]) -> Int:
    return len(v)


def takea(v: Array[Int, 2]) -> Int:
    return v[0]


def main():
    var x = 1
    var t = True
    var ab = [True, False]
    var ys: List[List[Int]] = [[1], [2]]
    print(([t, True] <= [ab[0], -x, []]) and t)
    print(len(ys))
