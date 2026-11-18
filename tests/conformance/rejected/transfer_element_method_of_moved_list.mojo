@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var l: List[S] = [S(1)]
    var m = l^
    print(l[0]^.k, len(m))
