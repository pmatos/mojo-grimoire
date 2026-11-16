@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def get_y(ref p: Point) -> ref [p] Int:
    ref r = p.y
    return r


def main():
    var p = Point(1, 2)
    print(get_y(p))
