@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var l: List[S] = [S(1)]
    var n: List[Int] = [0]
    ref r = n[0]
    n.append(1)
    var u = l[r]^
    print(u.k)
