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
        d = Duo(Mark(1), Mark(2))
    d.a = Mark(3)
    d.b = Mark(4)
    print("end")
