@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def bump(r: Res):
    r.id += 1


def main():
    var a = Res(1)
    bump(a)
