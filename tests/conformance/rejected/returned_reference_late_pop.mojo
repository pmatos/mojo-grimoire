def pick(ref a: Int, ref b: Int, first: Bool) -> ref[a, b] Int:
    if first:
        return a
    return b


def main():
    var xs: List[Int] = [1, 2]
    var b = 5
    print(pick(xs[0], b, True), xs.pop())
