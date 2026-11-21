@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var P = 5
    var ys: List[Int] = []
    ys = List[P]()
    print(len(ys), P)
