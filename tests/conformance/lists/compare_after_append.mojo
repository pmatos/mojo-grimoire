def main():
    var xs: List[Int] = [1, 2]
    var ys: List[Int] = [1, 2]
    var b = xs == ys
    xs.append(3)
    print(b, xs == ys, len(xs), len(ys))
