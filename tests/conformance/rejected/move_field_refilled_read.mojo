@fieldwise_init
struct Point(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Line(Movable):
    var start: Point
    var end: Point


def show(p: Point):
    print(p.x, p.y)


def main():
    var line = Line(Point(1, 2), Point(3, 4))
    var s = line.start^
    line.start.x = 5
    line.start.y = 6
    show(line.start)
    line.start = Point(7, 8)
    print(s.x, line.start.x)
