@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var s = S(7)
    var u = s.nope^
