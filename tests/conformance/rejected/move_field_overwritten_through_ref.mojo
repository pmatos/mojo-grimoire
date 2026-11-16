@fieldwise_init
struct Point(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Line(Movable):
    var start: Point
    var end: Point


def main():
    var line = Line(Point(1, 2), Point(3, 4))
    ref r = line
    var s = line.start^
    r = Line(Point(5, 6), Point(7, 8))
    line.start = Point(9, 10)
    print(s.x, line.start.x)
