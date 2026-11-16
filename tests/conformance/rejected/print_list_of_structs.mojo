@fieldwise_init
struct Point(Copyable, Movable):
    var x: Int


def main():
    var ps: List[Point] = [Point(1), Point(2)]
    print(ps)
