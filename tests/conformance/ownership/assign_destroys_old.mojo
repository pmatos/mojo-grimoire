@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def main():
    var a = Res(1)
    print("before")
    a = Res(2)
    print("after", a.id)
