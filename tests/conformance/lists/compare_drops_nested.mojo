@fieldwise_init
struct H(Movable):
    var n: Int
    var xs: List[List[Bool]]

    def __deinit__(deinit self):
        print("del", self.n)


def main():
    var h = H(1, [[True]])
    var g = H(2, [[False]])
    print(h.xs == g.xs, h.xs != g.xs)
