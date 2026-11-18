@fieldwise_init
struct Mark(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("mark gone")


@fieldwise_init
struct Bin(Movable):
    var a: Mark
    var b: Mark

    def __deinit__(deinit self):
        print("bin gone")


def main():
    var c = True
    var b: Bin
    if c:
        b.a = Mark(1)
    print("end")
