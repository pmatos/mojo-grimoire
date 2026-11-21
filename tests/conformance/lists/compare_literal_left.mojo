def main():
    var xs: List[Int] = [1, 2]
    print([1, 2] == xs, [1] != xs)
    var xss: List[List[Int]] = [[1], []]
    print([[1], []] == xss)
    var es: List[Int] = []
    print([] == es)
    var ys: List[Int] = [1]
    var x = 1
    print([x] == ys, [[1]] == ys)
    var zs: List[Array[Int, 1]] = [[1]]
    print([[1]] == zs, [[[1]]] == zs)
