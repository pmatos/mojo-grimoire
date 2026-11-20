@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    var s = S(1 + True)
    print(s.n)
