@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def make(id: Int) -> Res:
    var r = Res(id)
    print("made", id)
    return r^


def main():
    var a = make(3)
    print("got", a.id)
