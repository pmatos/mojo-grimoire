@fieldwise_init
struct H(Movable):
    var n: Int
    var a: Array[Int, 2]

    def __deinit__(deinit self):
        print("del", self.n)


def main():
    var h = H(1, [1, 2])
    var g = H(2, [1, 3])
    print(h.a < g.a)
    var k = H(3, [1, 2])
    var m = H(4, [1, 1])
    if m.a < k.a:
        print("lt")
    print(k.a == [1, 2], "end")
