def total(xs: List[Int]) -> Int:
    var s = 0
    var i = 0
    while i < len(xs):
        s += xs[i]
        i += 1
    return s


def main():
    var xs: List[Int] = [3, 1, 4, 1, 5, 9]
    print(total(xs))
