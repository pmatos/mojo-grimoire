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
    print("after", s.id)
    var i = 0
    while i < 2:
        s = make(peek(s))
        print("in", s.id)
        i += 1
    print("end", s.id)
