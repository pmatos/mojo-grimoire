@fieldwise_init
struct S(Movable):
    var k: Int

def f(x: Int):
    pass

def main():
    var s = S(7)
    var u = [True, s.nope]
