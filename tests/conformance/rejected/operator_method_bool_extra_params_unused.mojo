struct T(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(mut self, a: Int, b: Int):
        pass


def main():
    var t = T(1)
    print(t.n)
