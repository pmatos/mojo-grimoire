@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var xs = [Res(1), Res(2)]
    var n = xs[0].id^
    print(n)
