@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def get_x(p: Point) -> ref [p] Int:
    return p.x


def main():
    var p = Point(1, 2)
    print(get_x(p))
