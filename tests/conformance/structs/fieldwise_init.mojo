@fieldwise_init
struct Point(Copyable, Movable):
    var x: Int
    var y: Int


def main():
    var p = Point(3, 4)
    p.x += 10
    print(p.x, p.y)
