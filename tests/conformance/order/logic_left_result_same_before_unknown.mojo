struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Int:
        return self.n


def main():
    var t0 = T(1)
    var r = t0 or zz
