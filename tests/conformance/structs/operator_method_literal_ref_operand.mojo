struct B(Movable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __add__(mut self, ref o: Int) -> Int:
        self.n += 1
        return o

    def __radd__(mut self, ref o: Int) -> Int:
        self.n += 1
        return o


def main():
    var b = B(2)
    print(b + [b.n])
    print([b.n] + b)
    print(b.n)
