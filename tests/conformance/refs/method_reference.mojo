@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Holder(Movable):
    var res: Res

    def get(ref self) -> ref [self] Holder:
        return self


def main():
    var h = Holder(Res(1))
    ref r = h.get()
    print("x")
    r.res.id = 7
    print("via ref", h.res.id)
    print("end")
