@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Pair(Movable):
    var r: Res
    var k: Int

    def me(ref self) -> ref [self] Pair:
        return self


def pick(ref x: Int) -> ref [x] Int:
    return x


def setk(mut x: Int):
    x = 9


def main():
    var a = Pair(Res(1), 7)
    setk(pick(a^.k))
    print(a.k)
