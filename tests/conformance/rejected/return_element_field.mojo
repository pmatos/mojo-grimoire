@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def first_y(ref ps: List[Point]) -> ref [ps] Int:
    return ps[0].y


def main():
    var ps: List[Point] = [Point(1, 2)]
    print(first_y(ps))
