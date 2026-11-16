@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def make(r: Res) -> Res:
    return Res(r.id + 10)


def main():
    var b = Res(1)
    make(b)
    print("end")
