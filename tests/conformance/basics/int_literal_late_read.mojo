@fieldwise_init
struct Tag(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("gone", self.n)


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def pair(a: Int, b: Int) -> Int:
    return a * 100 + b


def loud(n: Int) -> Int:
    print("loud", n)
    return n


def main():
    var x = 1
    print([x] + bump(x))
    print(pair([x], bump(x)))
    var ys: List[Int] = [[x], bump(x)]
    print(ys)
    var t = Tag(4)
    print([t.n] + loud(2))
