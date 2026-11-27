def main():
    var t = True
    var ys: List[List[Int]] = [[1], [2]]
    var al: Array[List[Int], 2] = [[1], [2]]
    print(t or ([[2], ys[0]] == al))
