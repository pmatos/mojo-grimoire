struct Pair(Movable):
    var x: Int
    var y: Int

    def __init__(out self, x: Int):
        self.x = x


def main():
    var p = Pair(1)
    print(p.x)
