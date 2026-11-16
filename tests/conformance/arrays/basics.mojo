def main():
    var xs = [1, 2, 3]
    xs[1] = 20
    xs[2] += 5
    var i = 2
    var ys = xs.copy()
    ys[0] = 9
    print(len(xs), xs[0], xs[1], xs[i], ys[0])
