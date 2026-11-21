@fieldwise_init
struct P(Movable):
    var x: Int


def main():
    var p = P(1)
    p[0] = 1
    print(p.x)
