def show(k: Int) -> Int:
    print("eval", k)
    return k


def main():
    var xs: List[List[Int]] = [[1, 2], [3]]
    xs[show(5)][show(0)] = show(7)
    print(xs[0][0])
