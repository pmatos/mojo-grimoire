@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct P(Movable):
    var x: Int

@fieldwise_init
struct H(Movable):
    var l: List[Int]
    var s: S

def f(h: H):
    h.s.nope = 1

def main():
    f(H([1], S(0)))
