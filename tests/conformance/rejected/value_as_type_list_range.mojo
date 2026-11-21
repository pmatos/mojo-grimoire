@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var Int = 5
    print(len(List[Int](range(3))), Int)
