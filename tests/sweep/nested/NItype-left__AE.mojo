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


def bothi(mut a: Int, mut b: Int) -> Int:
    a += 1
    b += 1
    return a + b


def main():
    var pp = Point(1, 2)
    var te: List[Point] = [Point(1, 2)]
    var icr = Res(1)
    var om2: List[Int] = [1]
    var ae2 = 1
    var uu: Int
    var ae = 1
    var om: List[Int] = [1]
    var tl: List[Point] = [Point(1, 2)]
    var o = Point(bothi(ae2, ae2), True)
