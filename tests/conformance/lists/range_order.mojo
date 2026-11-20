def f(x: Int) -> Int:
    print("f", x)
    return x


def bump(mut x: Int) -> Int:
    x += 10
    return 3


def main():
    print(List[Int](range(f(1), f(10), f(3))))
    var x = 1
    print(List[Int](range(x, bump(x))))
    var y = 1
    print(List[Int](range(bump(y), y)))
