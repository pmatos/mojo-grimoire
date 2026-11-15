@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def consume(var r: Res):
    print(r.id)


def take(r: Res):
    consume(r^)


def main():
    var a = Res(1)
    take(a)
