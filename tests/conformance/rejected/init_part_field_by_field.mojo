@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


struct Seg(Movable):
    var lo: Pair
    var hi: Pair

    def __init__(out self):
        self.lo.x = 1
        self.lo.y = 2
        self.hi = Pair(3, 4)


def main():
    var s = Seg()
    print(s.hi.y)
