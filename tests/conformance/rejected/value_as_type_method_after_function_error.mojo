@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


@fieldwise_init
struct Q(Copyable, Movable):
    var x: Int

    def m(self, P: Int, q: P) -> Int:
        return self.x


def main():
    print(zz)
