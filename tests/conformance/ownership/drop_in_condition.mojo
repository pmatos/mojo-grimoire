@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def idof(r: Res) -> Int:
    return r.id


def show(x: Int) -> Int:
    print("show", x)
    return x


def main():
    var f = Res(1)
    var g = Res(2)
    if idof(f) == show(1):
        print("then", g.id)
    else:
        print("else")
    print("end")
