@fieldwise_init
struct P(Movable):
    var a: Int


def main():
    var p = P(4)
    var q = p^
    print(len(p), q.a)
