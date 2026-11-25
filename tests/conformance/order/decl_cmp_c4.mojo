@fieldwise_init
struct S(Movable):
    var k: Int

def f(x: Int):
    pass

def main():
    var xs: List[Int] = [1, 2]
    var b: Int = xs
