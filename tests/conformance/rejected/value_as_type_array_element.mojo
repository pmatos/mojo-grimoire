@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


def main():
    var Int = 5
    var a: Array[Int, 2] = [1, 2]
    print(a[0], Int)
