@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def consume(var r: Res):
    print("consuming", r.id)


def main():
    var a = Res(1)
    var go = True
    if go:
        consume(a^)
    else:
        print("kept", a.id)
    print("end")
