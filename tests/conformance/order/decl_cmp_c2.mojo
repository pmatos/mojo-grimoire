@fieldwise_init
struct S(Movable):
    var k: Int

def f(x: Int):
    pass

def main():
    var y: List[Int] = [1]
    var rl: List[List[Int]] = [[1]]
    print([[1], y] >= rl)
