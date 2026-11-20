@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    var S = 5
    var s = S(1)
    print(s.n)
