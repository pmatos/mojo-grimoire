@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var a: Array[S, 2] = [S(1), S(2)]
    ref t = a
    var u = t[5]^
    print(u.k)
