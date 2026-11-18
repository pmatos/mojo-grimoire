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
    var i = 0
    var d: Duo
    while i < 2:
        d = Duo(Token(i), Token(i + 10))
        var t = d.left^
        print(t.n)
        i = i + 1
    d.left = Token(7)
    print("end")
