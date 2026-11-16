@fieldwise_init
struct Holder(Movable):
    var xs: Array[Int, 2]


def make() -> Array[Int, 2]:
    return [7, 8]


def bump(mut xs: Array[Int, 2]):
    xs[0] += 1


def total(xs: Array[Int, 2]) -> Int:
    return xs[0] + xs[1]


def main():
    var xs = make()
    bump(xs)
    print(total(xs))
    var h = Holder(xs^)
    h.xs[1] = 5
    print(h.xs[0], h.xs[1])
