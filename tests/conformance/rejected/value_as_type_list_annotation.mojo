@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var Int = 5
    var ys: List[Int] = [1, 2]
    print(len(ys), Int)
