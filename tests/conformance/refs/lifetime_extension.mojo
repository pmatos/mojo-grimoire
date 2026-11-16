@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def first(ref a: Res) -> ref [a] Res:
    return a


def main():
    var a = Res(1)
    ref r = first(a)
    print("x")
    print("via ref", r.id)
    print("end")
