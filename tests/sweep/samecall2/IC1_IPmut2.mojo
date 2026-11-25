@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


@fieldwise_init
struct Line(Movable):
    var start: Point
    var end: Point


def one(x: Int) -> Int:
    return x


def two(x: Int, y: Int) -> Int:
    return x + y


def both(mut a: Int, mut b: Int):
    a += 1
    b += 1


def mutf(mut a: Int, b: Int):
    a += b


def both3(mut a: Int, mut b: Int, c: Int):
    a += c
    b += c


def takeb(b: Bool) -> Int:
    return 1


def takeres(var r: Res) -> Int:
    return r.id


def mkline() -> Line:
    return Line(Point(1, 2), Point(3, 4))


def tmut(b: Bool, mut a: Int):
    a += 1


def cmut(var r: Res, mut a: Int):
    a += r.id


def ctm(var r: Res, b: Bool):
    pass


def mutc(mut a: Int, var r: Res):
    a += r.id


def main():
    var icr = Res(1)
    cmut(icr, 1)
