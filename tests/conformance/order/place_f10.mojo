@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct P(Movable):
    var x: Int

def main():
    var p = P(1)
    var q = P(2)
    var r = q^
    p[0] = q^
