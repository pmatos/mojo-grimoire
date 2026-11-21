def main():
    var xs: List[Int] = [1, 2]
    var ys: List[Int] = [1, 2]
    var zs: List[Int] = [1, 3]
    var es = List[Int]()
    print(xs == ys, xs != ys, xs == zs, xs != zs, es == List[Int](), xs == es)
    print(xs == [1, 2], xs != [1], ys == [])
    print(xs, ys)
