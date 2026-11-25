@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct Q(Movable):
    var s: S

def f(x: Int, q: Q, l: List[Int]):
    l[zz] = 1

def main():
    f(1, Q(S(1)), [1])
