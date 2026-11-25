@fieldwise_init
struct P(Movable):
    var a: Int


def main():
    var p = P(1)
    p^.a = True
