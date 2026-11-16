@fieldwise_init
struct Point(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Line(Movable):
    var start: Point
    var end: Point


def f(mut line: Line, early: Bool):
    var s = line.start^
    if early:
        print(s.x)
        return
    line.start = s^


def main():
    var line = Line(Point(1, 2), Point(3, 4))
    f(line, True)
    print(line.start.x)
