struct Pair(Movable):
    var x: Int
    var y: Int

    def __init__(out self, x: Int, early: Bool):
        self.x = x
        if early:
            return
        self.y = x


def main():
    var p = Pair(1, True)
    print(p.x)
