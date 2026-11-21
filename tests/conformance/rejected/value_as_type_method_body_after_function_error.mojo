@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


@fieldwise_init
struct Q(Copyable, Movable):
    var x: Int

    def m(self) -> Int:
        var P = 5
        var q: P = mk()
        return q.x + P


def main():
    print(zz)
