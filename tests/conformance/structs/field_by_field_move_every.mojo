@fieldwise_init
struct Token(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("drop", self.n)


@fieldwise_init
struct Duo(Movable):
    var left: Token
    var right: Token


def main():
    var d: Duo
    d.right = Token(2)
    d.left = Token(1)
    var r = d.right^
    var l = d.left^
    print(r.n, l.n)
