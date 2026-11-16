@fieldwise_init
struct Holder(Movable):
    var xs: List[Int]


def first(ref h: Holder) -> ref [h] Int:
    return h.xs[0]


def main():
    var h = Holder([1, 2])
    print(first(h))
