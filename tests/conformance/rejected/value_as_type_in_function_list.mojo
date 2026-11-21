@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def f(Int: Bool) -> Int:
    var xs = List[Int]()
    return len(xs)


def main():
    print(f(True))
