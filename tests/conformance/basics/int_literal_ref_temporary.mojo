def pick(ref a: Int) -> ref [a] Int:
    return a


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def main():
    var x = 1
    print(pick([x]) + bump(x))
    var xs: List[Int] = [5, 6]
    print(pick([xs[0]]) + xs.pop())
    print(x, xs)
