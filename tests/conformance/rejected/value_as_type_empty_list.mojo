@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var P = 5
    var ys = List[P]()
    ys.append(mk())
    print(len(ys), P)
