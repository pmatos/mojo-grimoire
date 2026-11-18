@fieldwise_init
struct Pair(Movable):
    var x: Int
    var y: Int


def main():
    var p: Pair
    p.x = 1
    p.y = 2
    print(p.x, p.y)
    p.x = p.x + p.y
    print(p.x)
