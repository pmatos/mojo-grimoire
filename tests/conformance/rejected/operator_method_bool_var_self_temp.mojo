struct S(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(var self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del", self.n)


def mk(n: Int) -> S:
    return S(n)


def main():
    var r = mk(0) or mk(4)
    print("r", r.n)
