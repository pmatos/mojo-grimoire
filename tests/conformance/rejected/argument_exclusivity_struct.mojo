@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def swap_ids(mut a: Res, mut b: Res):
    var t = a.id
    a.id = b.id
    b.id = t


def main():
    var x = Res(1)
    swap_ids(x, x)
    print(x.id)
