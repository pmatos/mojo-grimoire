def main():
    var xs: List[Array[Int, 2]] = [[1, 2]]
    print(xs == [[[1], [2]]], [[[1], [2]]] == xs)
    var ys: List[List[Int]] = [[1]]
    print(ys == [[[1]]], [[[1]]] == ys)
