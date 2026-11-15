@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def show(r: Res):
    print("showing", r.id)


def main():
    show(Res(7))
    print("after")
