@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def f(xs: List[Int]):
    xs[0] = True


def main():
    var xs: List[Int] = [1, 2]
    f(xs)
