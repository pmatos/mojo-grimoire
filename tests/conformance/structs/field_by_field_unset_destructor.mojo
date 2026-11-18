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


def main():
    var b: Box
    b.a = Token(1)
    print(b.a.n)
