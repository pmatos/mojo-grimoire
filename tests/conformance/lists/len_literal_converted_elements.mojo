@fieldwise_init
struct S(Movable):
    var k: Int

def main():
    var s = S(4)
    var a = 3
    var xs: List[Int] = [1]
    var ys: List[Int] = [2]
    print(len([xs.copy(), [a], [s.k, a]]), len([xs.copy(), ys^, [1]]))
