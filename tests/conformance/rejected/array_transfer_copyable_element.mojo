@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int


def main():
    var ps = [Point(1, 2), Point(3, 4)]
    var p = ps[1]^
    print(p.y)
