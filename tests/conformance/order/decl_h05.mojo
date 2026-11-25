@fieldwise_init
struct S(Movable):
    var k: Int

def f(x: Int):
    pass

def main():
    var s = S(7)
    var u = [f(1), f(2)]
    print(len(u))
