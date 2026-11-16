@fieldwise_init
struct Res(Movable):
    var id: Int


def first(ref xs: List[Res]) -> ref [xs] List[Res]:
    return xs


def build(mut ys: List[Res]) -> Res:
    return Res(len(ys))


def main():
    var xs: List[Res] = [Res(1), Res(2)]
    xs[0] = build(first(xs))
    print(xs[0].id)
