@fieldwise_init
struct S(Movable):
    var k: Int

def main():
    var s = S(7)
    var xs: List[Int] = [1, 2]
    var ys: List[Int] = [1]
    var b: Int = s
