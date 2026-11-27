@fieldwise_init
struct T(Movable):
    var n: Int

    def __bool__(var self) -> Bool:
        return self.n != 0


@fieldwise_init
struct H(Movable):
    var t: T


def f(mut t0: T) -> Bool:
    var h = H(T(1))
    var hl: List[H] = [H(T(1))]
    ref rr = t0
    return not hl[(h.t or rr^)].t


def main():
    print(1)
