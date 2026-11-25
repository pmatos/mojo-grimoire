@fieldwise_init
struct T(Copyable, Movable):
    var a: Int

def f(xs: List[Int]):
    var j: Int
    xs[j] = 5


def main():
    var xs: List[Int] = [1, 2]
    f(xs)
