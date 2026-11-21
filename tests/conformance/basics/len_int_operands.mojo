def bump(mut x: Int) -> Int:
    x += 1
    return x


def size(a: Int) -> Int:
    return len(a)


def main():
    var x = 1
    var ys: List[Int] = [1, 2]
    print(len(x), bump(x), len(x), x, size(9), len(len(ys)))
    var zs = List[Int](range(len(x)))
    print(len(zs), zs[0])
