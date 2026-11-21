@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var Bool = 5
    var b: Bool = True
    print(b, Bool)
