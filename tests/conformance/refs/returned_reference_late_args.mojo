def pick(ref a: Int, ref b: Int, first: Bool) -> ref[a, b] Int:
    if first:
        return a
    return b


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def two(x: Int, y: Int) -> Int:
    print(x, y)
    return x


def own(var x: Int, y: Int) -> Int:
    print(x, y)
    return x


@fieldwise_init
struct C(Movable):
    var v: Int
    var w: Int

    def add(mut self, x: Int, y: Int) -> Int:
        print(x, y)
        return x


def bump_c(mut c: C) -> Int:
    c.v += 100
    return 0


def main():
    var a = 1
    var b = 2
    print(two(pick(a, b, True), bump(a)))
    print(own(pick(a, b, True), bump(a)))
    var c = C(pick(a, b, True), bump(a))
    print(c.v, c.w)
    var d = C(5, 6)
    print(d.add(pick(c.v, b, True), bump_c(c)))
