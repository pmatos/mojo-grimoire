def bump(mut n: Int) -> List[Int]:
    n += 1
    return [1, 2]


def main():
    var n = 1
    print(bump(n) == [1, n])
