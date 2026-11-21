@fieldwise_init
struct H(Movable):
    var n: Int
    var xs: List[Int]

    def __deinit__(deinit self):
        print("del", self.n)


def main():
    var h = H(1, [1, 2])
    var g = H(2, [1, 2])
    print(h.xs == g.xs)
    var k = H(3, [1])
    if k.xs != [2]:
        print("ne")
    print("end")
