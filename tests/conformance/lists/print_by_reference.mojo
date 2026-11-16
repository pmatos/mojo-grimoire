@fieldwise_init
struct Bag(Movable):
    var items: List[Int]


def show(xs: List[Int]):
    print("read", xs)


def grow(mut xs: List[Int]):
    print("mut", xs)
    xs.append(9)


def pick(ref a: List[Int], ref b: List[Int], first: Bool) -> ref[a, b] List[Int]:
    if first:
        return a
    return b


def main():
    var xs: List[Int] = [7]
    show(xs)
    grow(xs)
    ref r = xs
    print("ref", r, len(xs))
    var bag = Bag([4, 5])
    print("field", bag.items)
    var ys: List[Int] = [3]
    print("picked", pick(xs, ys, False))
