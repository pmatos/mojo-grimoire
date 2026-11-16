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
    var s = Point(0, 0)
    var i = 0
    while i < 1:
        s = line.start^
        line.start.x = 5
        line.start.y = 6
        i = i + 1
    line.start = Point(7, 8)
    print(s.x, line.start.x)
