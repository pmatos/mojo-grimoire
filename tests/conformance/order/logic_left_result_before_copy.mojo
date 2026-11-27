struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Int:
        return self.n


def main():
    var t2 = T(1)
    var lT: List[T] = [T(0)]
    var r = lT[0] or t2
