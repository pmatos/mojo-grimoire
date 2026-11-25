@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct P(Movable):
    var x: Int

def main():
    var a: Array[S, 1] = [S(0)]
    print(a[3].nope)
