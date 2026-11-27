@fieldwise_init
struct H(Movable):
    var y: List[Int]
    var x: Int
def g3(v: H) -> Bool:
    return True
def g4(v: H) -> List[List[Int]]:
    return [[1]]
def main():
    var x = 1
    var t = True
    var y: List[Int] = [1]
    print([y] == x + t)
