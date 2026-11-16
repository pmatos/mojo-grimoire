@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def peek(r: Res) -> Int:
    print("peek", r.id)
    return r.id


def make(k: Int) -> Res:
    print("make", k)
    return Res(k + 100)


def main():
    var s = Res(1)
    s = make(peek(s))
    print("after")
