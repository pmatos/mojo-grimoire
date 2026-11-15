@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def two(x: Res, y: Res) -> Int:
    return x.id + y.id


def by_reference() -> Int:
    var a = Res(1)
    var b = Res(2)
    return two(a, b)


def by_value() -> Int:
    var a = Res(3)
    var b = Res(4)
    return a.id + b.id


def main():
    print(by_reference())
    print(by_value())
