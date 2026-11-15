@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def take(var p: Res, var q: Res):
    var l = Res(30)
    var m = Res(31)
    print("in take", p.id, m.id, q.id, l.id)


def main():
    take(Res(10), Res(20))
    var a = Res(1)
    var b = Res(2)
    var c = Res(3)
    print(a.id, c.id, b.id)
    print("end")
