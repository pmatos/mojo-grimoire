def first(xs: List[Int]) -> Int:
    return xs[0]^


def shift(mut xs: List[Int]):
    xs[1] = xs[0]^


def take(var x: Int):
    print("take", x)


def two(x: Int, y: Int):
    print(x, y)


def bump(mut x: Int) -> Int:
    x += 10
    return x


def main():
    var xs: List[Int] = [1, 2, 3]
    var i = 1
    var r = xs[i]^
    print(r, xs[i])
    var bs: List[Bool] = [True, False]
    var b = bs[1]^
    print(b, bs[1])
    print(first(xs))
    shift(xs)
    print(xs[0], xs[1])
    take(xs[2]^)
    print(xs[2])
    two(xs[0]^, bump(xs[0]))
    var ys: List[List[Int]] = [[4, 5], [6]]
    var y = ys[0][1]^
    print(y, ys[0][1])
