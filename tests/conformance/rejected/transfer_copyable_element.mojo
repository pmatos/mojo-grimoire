@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def main():
    var ps: List[Point] = [Point(1, 2)]
    var p = ps[0]^
    print(p.x)
