@fieldwise_init
struct H(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("del", self.n)


def get(h: H) -> Int:
    return h.n


def main():
    var h = H(1)
    var g = H(2)
    print([get(h)] == [get(g)], [get(h)] < [get(g)])
