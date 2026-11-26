@fieldwise_init
struct S(Movable):
    var k: Int

def f(x: Int):
    pass

def main():
    var y: List[Int] = [1]
    var al: Array[List[Int], 1] = [[1]]
    print([y] > al)
