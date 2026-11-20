@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    print(S(1) + 1)
