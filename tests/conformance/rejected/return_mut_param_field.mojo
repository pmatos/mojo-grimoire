@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def get_x(mut p: Point) -> ref [p] Int:
    return p.x


def main():
    var p = Point(1, 2)
    ref x = get_x(p)
    x = 5
    print(p.x)
