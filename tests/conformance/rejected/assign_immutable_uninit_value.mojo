@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def f(xs: List[Int]):
    var j: Int
    xs[0] = j


def main():
    var xs: List[Int] = [1, 2]
    f(xs)
