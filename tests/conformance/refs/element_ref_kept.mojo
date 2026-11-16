def main():
    var xs: List[Int] = [1, 2]
    ref second = xs[1]
    xs[0] = 7
    second = 9
    print(xs[0], xs[1], len(xs))
    var ys = xs.copy()
    print(second, len(ys))
    var arr = [5, 6]
    ref a0 = arr[0]
    arr = [8, 9]
    print(a0)
    print(xs.pop(), len(xs))
