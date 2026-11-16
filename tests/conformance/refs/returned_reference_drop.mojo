@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def first(ref xs: List[Res]) -> ref [xs] List[Res]:
    return xs


def two(a: List[Res], b: Int) -> Int:
    return len(a) + b


def main():
    var xs: List[Res] = [Res(1), Res(2)]
    print(len(first(xs)))
    print("a")
    var ys: List[Res] = [Res(3)]
    print(two(first(ys), 10))
    print("b")
    var zs: List[Res] = [Res(4)]
    print(len(first(first(zs))))
    print("c")
