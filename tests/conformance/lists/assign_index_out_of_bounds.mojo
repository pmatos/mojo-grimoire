def show(k: Int) -> Int:
    print("eval", k)
    return k


def main():
    var xs: List[Int] = [1, 2]
    xs[show(5)] = show(7)
    print(xs[0])
