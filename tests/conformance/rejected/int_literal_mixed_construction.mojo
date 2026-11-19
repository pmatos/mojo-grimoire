@fieldwise_init
struct Point(Movable):
    var x: Int


def main():
    var p = Point([1, True])
    print(p.x)
