@fieldwise_init
struct Token(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("drop", self.n)


@fieldwise_init
struct Duo(Movable):
    var left: Token
    var right: Token


def show(t: Token):
    print("show", t.n)


def main():
    var d: Duo
    d.left = Token(4)
    show(d.left)
    print(d.left.n)
    var t = d.left^
    print(t.n)
