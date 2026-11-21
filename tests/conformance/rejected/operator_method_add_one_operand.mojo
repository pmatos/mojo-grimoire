struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __add__(self) -> Int:
        return self.n


def main():
    var t = T(1)
    print(t.n)
