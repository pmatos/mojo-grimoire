def grow(mut xs: List[Int]) -> Int:
    xs.append(1)
    return 0


def main():
    var xs: List[Int] = []
    var ys: List[Int] = [1]
    print(xs == ys, grow(xs), xs == ys)
