@fieldwise_init
struct S(Movable):
    var k: Int


def main():
    var l: List[S] = [S(1)]
    ref t = l[0]
    l.append(S(2))
    var u = t^
    print(u.k)
