@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var a = Res(1)
    print("start")
    var b = Res(2)
    print("b", b.id)
