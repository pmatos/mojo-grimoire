def main():
    var xs: List[Int] = [1]
    var ys: List[Int] = [1]
    ref r = xs
    print(r == ys, ys == r, r != [2])
