@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    var s = S(1)
    print(1 + s)
