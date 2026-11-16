@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Pair(Movable):
    var first: Res
    var second: Res


@fieldwise_init
struct Point(Movable):
    var x: Int
    var y: Int


@fieldwise_init
struct Line(Movable):
    var start: Point
    var end: Point


def main():
    var p = Pair(Res(1), Res(2))
    var r = p.first^
    print("second", p.second.id)
    p.first = Res(3)
    print("first", p.first.id, r.id)
    var line = Line(Point(1, 2), Point(3, 4))
    var s = line.start^
    line.start = Point(s.y, s.x)
    print(line.start.x, line.end.y)
