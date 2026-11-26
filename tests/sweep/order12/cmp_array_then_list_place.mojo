@fieldwise_init
struct H(Movable):
    var y: List[Int]
    var x: Int
def main():
    var x = 1
    var y: List[Int] = [1]
    var rl: List[List[Int]] = [[1]]
    var al: Array[List[Int], 1] = [[1]]
    var h = H([1], 1)
    var a = [1, 2]
    var n = [[1], [2]]
    var xs = [1, 2]
    print(al == [[x]], [y] > al)
