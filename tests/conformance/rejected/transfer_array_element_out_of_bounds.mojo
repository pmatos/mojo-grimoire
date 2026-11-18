@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var a: Array[S, 2] = [S(1), S(2)]
    var u = a[5]^
    print(u.k)
