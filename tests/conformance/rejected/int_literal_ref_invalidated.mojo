def both(ref a: Int, b: Int) -> Int:
    return a + b


def main():
    var xs: List[Int] = [1, 2]
    print(both([xs[0]], xs.pop()))
