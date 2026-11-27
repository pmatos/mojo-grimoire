@fieldwise_init
struct T(Movable):
    var n: Int

    def __bool__(var self) -> Bool:
        return self.n != 0


@fieldwise_init
struct H(Movable):
    var t: T


def f(t0: T, t2: T) -> T:
    var hl: List[H] = [H(T(2))]
    return hl[(t0 or t2^)].t


def main():
    print(1)
