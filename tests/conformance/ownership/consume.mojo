@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def consume(var r: Res):
    print("consuming", r.id)


def main():
    var a = Res(1)
    consume(a^)
    print("after")
