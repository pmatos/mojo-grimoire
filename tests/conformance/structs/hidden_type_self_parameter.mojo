@fieldwise_init
struct P(Copyable, Movable):
    var x: Int


def mk() -> P:
    return P(4)


@fieldwise_init
struct Q(Copyable, Movable):
    var x: Int

    def m(self, Q: Int, o: Self) -> Int:
        return o.x + Q


def main():
    var a = Q(1)
    print(a.m(2, Q(3)))
