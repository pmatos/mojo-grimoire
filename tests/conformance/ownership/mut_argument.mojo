@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def bump(mut r: Res):
    r.id += 10


def main():
    var a = Res(1)
    bump(a)
    print("bumped", a.id)
