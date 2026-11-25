@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct P(Movable):
    var x: Int

def main():
    var p = P(1)
    print(p[zz])
