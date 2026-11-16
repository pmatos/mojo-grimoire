@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def first_y(ref ps: Array[Point, 1]) -> ref [ps] Int:
    return ps[0].y


def main():
    var ps: Array[Point, 1] = [Point(1, 2)]
    print(first_y(ps))
