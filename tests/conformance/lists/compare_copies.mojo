def main():
    var xs: List[Int] = [1]
    var ys: List[Int] = [1]
    print(xs.copy() == ys, List[Int](xs) == ys, ys != xs.copy())
