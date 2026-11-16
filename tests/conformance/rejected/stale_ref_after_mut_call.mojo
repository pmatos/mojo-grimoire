def extend(mut xs: List[Int]):
    xs.append(0)


def main():
    var xs: List[Int] = [1, 2]
    ref head = xs[0]
    extend(xs)
    print(head)
