@fieldwise_init
struct S(Movable):
    var k: Int


def consume(var s: S):
    print(s.k)


def main():
    var s = S(7)
    ref t = s
    consume(s^)
    var u = t^
    print(u.k)
