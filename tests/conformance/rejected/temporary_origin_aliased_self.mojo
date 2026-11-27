@fieldwise_init
struct M(Movable):
    var v: Int

    def cmp(ref self, ref o: M) -> Int:
        return self.v + o.v

    def __deinit__(deinit self):
        print("mdrop", self.v)


def mpick(ref a: M, ref b: M, first: Bool) -> ref [a, b] M:
    if first:
        return a
    return b


def main():
    var m = M(5)
    print(m.cmp(mpick(M(1), m, False)))
