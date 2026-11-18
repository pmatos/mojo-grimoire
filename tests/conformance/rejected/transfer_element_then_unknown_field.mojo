@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var l: List[S] = [S(1)]
    var u = l[0]^.nope^
    print(u.k)
