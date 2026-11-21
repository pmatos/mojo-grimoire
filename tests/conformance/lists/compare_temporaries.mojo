def mk(n: Int) -> List[Int]:
    print("mk", n)
    return [n]


def main():
    var xs: List[Int] = [1]
    print(mk(1) == xs, xs == mk(2), mk(3) != mk(3))
