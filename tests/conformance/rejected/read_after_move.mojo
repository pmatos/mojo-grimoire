@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def take(var r: Res) -> Int:
    return r.id


def two(x: Int, y: Int):
    print("two", x, y)


def main():
    var a = Res(1)
    two(a.id, take(a^))
