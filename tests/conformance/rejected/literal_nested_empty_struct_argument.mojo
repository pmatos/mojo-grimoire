@fieldwise_init
struct S(Movable):
    var k: Int


def h(x: S):
    pass


def main():
    h([[1], []])
