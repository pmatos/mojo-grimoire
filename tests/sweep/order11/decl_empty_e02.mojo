@fieldwise_init
struct S(Movable):
    var k: Int

def g(s: S) -> Int:
    return s.k

def main():
    var s = S(1)
    var ys: List[Int] = [1]
    var v = [[], [1, True]]
