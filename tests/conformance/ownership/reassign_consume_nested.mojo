@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)

    def consume(var self) -> Res:
        print("consume", self.id)
        return Res(self.id + 100)


def ident(var r: Res) -> Res:
    return r^


def main():
    var s = Res(1)
    s = ident(s^.consume())
    print("after")
