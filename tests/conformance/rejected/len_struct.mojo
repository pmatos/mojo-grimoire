@fieldwise_init
struct P(Copyable, Movable):
    var a: Int


def main():
    var p = P(4)
    print(len(p))
