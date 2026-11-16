@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var xs: List[Res] = [Res(1), Res(2)]
    var n = xs[1].id^
    print(n, xs[1].id)
    var a = [Res(3), Res(4)]
    var m = a[0].id^
    print(m, a[0].id)
