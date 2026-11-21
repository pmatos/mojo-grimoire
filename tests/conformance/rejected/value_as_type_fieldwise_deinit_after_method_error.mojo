@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


@fieldwise_init
struct R(Movable):
    var q: Int

    def m(self):
        print(zz)

    def __deinit__(deinit self):
        var P = 1
        var z: P = mk()
        print(z.x)


def main():
    print(1)
