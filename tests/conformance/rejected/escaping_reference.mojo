@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def bad(ref a: Res) -> ref [a] Res:
    var local = Res(2)
    return local


def main():
    var a = Res(1)
    ref r = bad(a)
    print(r.id)
