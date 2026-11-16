def pick(ref a: Int, ref b: Int, first: Bool) -> ref[a, b] Int:
    if first:
        return a
    return b


def pickb(ref a: Bool, ref b: Bool, first: Bool) -> ref[a, b] Bool:
    if first:
        return a
    return b


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def flip(mut x: Bool) -> Bool:
    x = not x
    return True


def main():
    var a = 1
    var b = 2
    print(pick(a, b, True), bump(a))
    print(pick(a, b, True) + bump(a))
    print(pick(a, b, True) == bump(a) + 31)
    print(-pick(a, b, True), bump(a))
    a = pick(a, b, True) * 2 + bump(a)
    print(a)
    var xs: List[Int] = [1, 2]
    print(pick(xs[0], b, True) + len(xs))
    var p = True
    var q = False
    print(pickb(p, q, True) and flip(p))
    print(pickb(p, q, True) or flip(p))
    print(not pickb(p, q, True), flip(p))
