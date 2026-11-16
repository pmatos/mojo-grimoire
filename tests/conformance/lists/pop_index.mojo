def main():
    var xs: List[Int] = [1, 2, 3, 4]
    print(xs.pop(1), len(xs))
    print(xs[0], xs[1], xs[2])
    print(xs.pop(0), xs.pop(len(xs) - 1), len(xs))
    var ys: List[Int] = [5, 0, 1, 2]
    print(ys.pop(ys.pop()))
    print(ys.pop(ys[1]), len(ys), ys[0])
