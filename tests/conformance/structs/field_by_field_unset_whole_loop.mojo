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
    var i = 0
    var d: Duo
    while i < 2:
        d.a = Mark(i)
        d.b = Mark(i)
        i = i + 1
    print("end")
