def main():
    var xs: Array[Int, 2] = [1, 2]
    var ys: Array[Int, 2] = [1, 2]
    xs[[1, 2]] = ys[5]
    print(xs[0])
