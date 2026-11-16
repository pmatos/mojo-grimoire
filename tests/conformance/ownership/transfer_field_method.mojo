@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


@fieldwise_init
struct Pair(Movable):
    var r: Res
    var k: Int

    def next(self) -> Int:
        return self.k + 1

    def bump(mut self):
        self.k += 1

    def take(var self) -> Int:
        print("taking", self.k)
        return self.k

    def take_plus(var self, x: Int) -> Int:
        return self.k + x

    def take_with(var self, other: Pair) -> Int:
        return self.k + other.k


@fieldwise_init
struct Box(Copyable):
    var v: Int


def main():
    var a = Pair(Res(1), 7)
    print(a^.next())
    print(a.k)
    var b = Box(5)
    var c = b^.copy()
    print(c.v, b.v)
    var d = Pair(Res(2), 3)
    print(d^.take())
    var e = Pair(Res(4), 10)
    print(e^.take_plus(e.k))
    print("end")
