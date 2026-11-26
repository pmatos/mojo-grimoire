@fieldwise_init
struct P(Movable):
    var n: Int


def main():
    var p = P(1)
    print(p, [])
