@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def same(ref n: Int) -> ref [n] Int:
    return n


def get_y(ref p: Point) -> ref [p] Int:
    return same(p.y)


def main():
    var p = Point(1, 2)
    print(get_y(p))
