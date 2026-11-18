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


def main():
    var r: Rack
    r.z = 3
    print(r.z)
    var q: Rack
    q.s.k = 4
    print(q.s.k)
