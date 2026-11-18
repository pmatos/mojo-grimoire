@fieldwise_init
struct Token(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("drop", self.n)


@fieldwise_init
struct Slot(Movable):
    var t: Token
    var k: Int


@fieldwise_init
struct Rack(Movable):
    var s: Slot
    var z: Int


@fieldwise_init
struct Duo(Movable):
    var left: Token
    var right: Token


def main():
    var r: Rack
    r.s.k = 1
    print(r.s.k)
    r.s = Slot(Token(5), 2)
    print(r.s.k)
    var d: Duo
    d.left = Token(6)
    d = Duo(Token(7), Token(8))
    print(d.left.n)
