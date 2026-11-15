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


def size(xs: List[Res]) -> Int:
    return len(xs)


def main():
    var a = Res(1)
    var b = Res(2)
    print(show(idof(b) + idof(a)))
    var c = Res(3)
    var d = Res(4)
    print(show(idof(c)), show(d.id))
    var xs = List[Res]()
    xs.append(Res(5))
    print(size(xs))
    print("end")
