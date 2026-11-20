@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    var s = S(1)
    var t = S(1)
    print(s == t)
