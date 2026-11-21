struct P(Copyable):
    var v: Int

    def __init__(out self, v: Int):
        self.v = v

    def __add__(self, o: P) -> Bool:
        return True

    def __neg__(self) -> Bool:
        return True

    def __lt__(self, o: P) -> Int:
        return 1

    def __call__(self, k: Int) -> Int:
        return self.v + k


def main():
    var p = P(1)
    var bs: List[Bool] = [True]
    var xs: List[Int] = [1]
    print(bs == [p + p], bs != [-p], xs == [p < p])
    print([p + p] == bs, [p < p] == xs)
    var ys: List[Int] = [2]
    var a = [2]
    var c = [2, 3]
    print([p(1)] == ys, a == [[p(1)]], c == [p(1), [3]])
