@fieldwise_init
struct M(Movable):
    var f: Bool


def same(ref x: M) -> ref [x] M:
    return x


def main():
    var m = M(True)
    var xs: List[Int] = [1, 2, 3]
    print(xs[same(m)])
