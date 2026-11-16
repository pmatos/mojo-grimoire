@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var a = Res(1)
    var b = a^
    print(a.id, b.id)
