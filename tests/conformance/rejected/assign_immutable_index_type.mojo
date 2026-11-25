@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def tb(b: Bool) -> Int:
    return 0


def f(xs: List[Int]):
    xs[tb(1)] = 5


def main():
    var xs: List[Int] = [1, 2]
    f(xs)
