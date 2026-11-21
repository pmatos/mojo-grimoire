@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def h(xs: List[P]) -> Int:
    return len(xs)


def main():
    var P = 5
    print(h(List[P]()))
