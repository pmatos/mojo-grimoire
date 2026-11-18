@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var l: List[S] = [S(1)]
    ref t = l
    var u = t[-1]^
    print(u.k)
