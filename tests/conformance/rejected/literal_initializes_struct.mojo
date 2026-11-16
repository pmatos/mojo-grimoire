@fieldwise_init
struct Point(Movable):
    var x: Int
    var y: Int


def main():
    var p: Point = [1, 2]
    print(p.x)
