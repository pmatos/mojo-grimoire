def show(k: Int) -> Int:
    print("eval", k)
    return k


def bump(mut i: Int) -> Int:
    i += 1
    return 7


def main():
    var xs: Array[Int, 3] = [1, 2, 3]
    xs[show(1)] = show(7)
    print(xs[0], xs[1], xs[2])
    var i = 0
    xs[i] = bump(i)
    print(xs[0], xs[1], i)
