@fieldwise_init
struct S(Movable):
    var n: Int


def main():
    var xs: List[Int] = [5, 6]
    var s = S(0)
    print(xs[s].n)
