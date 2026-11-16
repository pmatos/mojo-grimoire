@fieldwise_init
struct Box(Movable):
    var v: Int


def bump(mut b: Box) -> Int:
    b.v += 100
    return 0


def bumpi(mut x: Int) -> Int:
    x += 10
    return 0


def two(x: Int, y: Int):
    print("two", x, y)


def main():
    var b = Box(1)
    two(b.v, bump(b))
    var k = 5
    print(k, bumpi(k))
    print(k + bumpi(k))
    var xs: List[Int] = [k, bumpi(k)]
    print(xs[0], xs[1])
