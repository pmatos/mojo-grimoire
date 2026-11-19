@fieldwise_init
struct Mark(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("mark gone")


@fieldwise_init
struct Duo(Movable):
    var a: Mark
    var b: Mark


def main():
    var c = True
    var d: Duo
    if c:
        d.a = Mark(1)
        d.b = Mark(2)
    print("end")
