@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def pick(ref a: Res, ref b: Res, first: Bool) -> ref [a, b] Res:
    if first:
        return a
    return b


def main():
    var a = Res(1)
    var b = Res(2)
    ref r = pick(a, b, True)
    print("picked", r.id)
    r.id = 100
    print("now", a.id)
