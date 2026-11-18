def make(n: Int) -> List[Int]:
    var xs = List[Int]()
    xs.append(n)
    xs.append(n + 1)
    return xs^


def main():
    var xs = List[Int](make(3))
    print(xs)
    print(List[Int](make(5)))
    var empty = List[Int](List[Int]())
    print(len(empty))
