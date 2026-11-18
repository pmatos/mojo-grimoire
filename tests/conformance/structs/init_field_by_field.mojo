struct Pair(Movable):
    var x: Int
    var y: Int

    def __init__(out self, n: Int):
        self.x = n
        self.y = n + 1

    def sum(self) -> Int:
        return self.x + self.y


def main():
    var p = Pair(3)
    print(p.sum())
