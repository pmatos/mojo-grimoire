def show(k: Int) -> Int:
    print("eval", k)
    return k


def bump(mut i: Int) -> Int:
    i += 1
    return 7


def reset(mut ys: List[Int]) -> Int:
    ys[0] = 1
    return 5


def main():
    var xs: List[Int] = [1, 2, 3]
    xs[show(1)] = show(7)
    print(xs[0], xs[1], xs[2])
    var i = 0
    xs[i] = bump(i)
    print(xs[0], xs[1], i)
    var ys: List[Int] = [2, 0]
    xs[ys[0]] = reset(ys)
    print(xs[0], xs[1], xs[2], ys[0])
    var zs: List[List[Int]] = [[1, 2], [3]]
    zs[show(0)][show(1)] = show(4)
    print(zs[0][0], zs[0][1])
