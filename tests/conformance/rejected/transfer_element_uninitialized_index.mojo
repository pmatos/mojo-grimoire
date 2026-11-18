@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var l: List[S] = [S(1)]
    var i: Int
    var u = l[i]^
    print(u.k)
