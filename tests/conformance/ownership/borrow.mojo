@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def show(r: Res):
    print("showing", r.id)


def main():
    var a = Res(1)
    show(a)
    show(a)
    print("after")
