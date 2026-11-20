@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    var b = False
    var s = S(1)
    print(b or s)
