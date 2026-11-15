@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var a = Res(1)
    var b = Res(2)
    print("use", a.id)
    print("use", b.id)
    print("end")
