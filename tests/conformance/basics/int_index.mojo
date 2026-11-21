@fieldwise_init
struct Box(Copyable, Movable):
    var k: Int


def inc(mut x: Int):
    x += 1


def first(x: Int) -> Int:
    return x[0]


def main():
    var k = 7
    print(k[0], k[0][0])
    k[0] = 5
    k[0] += 1
    print(k)
    var i = 0
    k[i] = k[i] * 2
    inc(k[0])
    print(k, first(k))
    var b = Box(3)
    b.k[0] = 4
    var xs: List[Int] = [1, 2]
    xs[1][0] = b.k[0]
    print(b.k, xs)
