@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct Q(Movable):
    var s: S

def f(x: Int, q: Q, l: List[Int]):
    q.s.k = q.s

def main():
    f(1, Q(S(1)), [1])
