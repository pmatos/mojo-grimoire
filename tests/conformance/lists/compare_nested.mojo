def main():
    var xs: List[List[Int]] = [[1], [2, 3]]
    var ys: List[List[Int]] = [[1], [2, 3]]
    var zs: List[List[Int]] = [[1], [2]]
    print(xs == ys, xs != ys, xs == zs, xs[1] == ys[1], xs[1] != zs[1])
    var bs: List[List[Bool]] = [[True]]
    var cs: List[List[Bool]] = [[False]]
    print(bs == cs, bs != cs)
