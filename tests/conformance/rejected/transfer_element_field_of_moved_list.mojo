@fieldwise_init
struct S(Movable):
    var k: Int


@fieldwise_init
struct O(Movable):
    var inner: S


def main():
    var l: List[O] = [O(S(1))]
    var m = l^
    var u = l[0].inner^
    print(u.k, len(m))
