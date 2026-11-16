@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Pair(Movable):
    var r: Res
    var k: Int


def main():
    var a = Pair(Res(1), 7)
    var r = a^.r^
    print("after", r.id)
