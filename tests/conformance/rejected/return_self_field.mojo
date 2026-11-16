@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Holder(Movable):
    var res: Res

    def get(ref self) -> ref [self] Res:
        return self.res


def main():
    var h = Holder(Res(1))
    ref r = h.get()
    print(r.id)
