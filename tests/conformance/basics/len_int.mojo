def g() -> Int:
    print("g")
    return 5


def main():
    var x = -7
    var xs: List[Int] = [5, 6]
    print(len(x), len(3 + 4), len(xs[1]), len(g()), x)
