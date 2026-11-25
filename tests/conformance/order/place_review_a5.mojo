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

def f(p: P):
    p.nope = zz

def main():
    f(P(1))
