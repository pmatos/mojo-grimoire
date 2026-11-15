@fieldwise_init
struct Point(Copyable, Movable):
    var x: Int


def main():
    var p = Point(1)
    print(p.y)
