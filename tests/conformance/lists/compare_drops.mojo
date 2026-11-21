@fieldwise_init
struct H(Movable):
    var n: Int
    var xs: List[Int]

    def __deinit__(deinit self):
        print("del", self.n)


def main():
    var h = H(1, [1])
    var g = H(2, [2])
    print(h.xs == g.xs)
    var k = H(3, [1])
    var m = H(4, [2])
    print(k.xs != m.xs)
    var p = H(5, [1, 2])
    var q = H(6, [1, 3])
    print(p.xs == q.xs, p.xs != q.xs)
