@fieldwise_init
struct Token(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("drop", self.n)


@fieldwise_init
struct Box(Movable):
    var a: Token
    var b: Token

    def __deinit__(deinit self):
        print("box")


@fieldwise_init
struct Duo(Movable):
    var left: Token
    var right: Token


def main():
    var b: Box
    b.a = Token(1)
    b.b = Token(2)
    print(b.a.n)
    var d: Duo
    d.left = Token(3)
    var t = d.left^
    print(t.n)
