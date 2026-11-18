@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


def show(p: Pair):
    print(p.x, p.y)


def main():
    var p: Pair
    p.x = 1
    p.y = 2
    show(p)
