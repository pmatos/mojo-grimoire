@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Plain(Movable):
    var first: Res
    var second: Res


def main():
    var p = Plain(Res(1), Res(2))
    print("made", p.first.id)
