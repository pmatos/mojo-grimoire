def g(xs: List[Int], h: Int):
    print(xs.pop(h()))


def main():
    var xs: List[Int] = [1]
    g(xs, 0)
