@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def main():
    var a = Res(1)
    var b = a
    print(b.id)
