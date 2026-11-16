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
    var s = line.start^
    print(s.x)
