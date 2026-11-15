@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Holder(Movable):
    var first: Res
    var second: Res

    def __deinit__(deinit self):
        print("holder", self.second.id)
        print("holder", self.first.id)


def main():
    var h = Holder(Res(1), Res(2))
    print("made")
