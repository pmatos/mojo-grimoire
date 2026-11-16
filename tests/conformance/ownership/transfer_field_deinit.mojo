@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop res", self.id)


@fieldwise_init
struct Holder(Movable):
    var r: Res
    var k: Int

    def __deinit__(deinit self):
        print("drop holder", self.k)

    def peek(self) -> Int:
        return self.k

    def take(var self) -> Int:
        print("taking", self.k)
        return self.k

    def take_plus(var self, x: Int) -> Int:
        return self.k + x


def main():
    var a = Holder(Res(1), 7)
    var y = a^.k
    print("after", y)
    var b = Holder(Res(2), 8)
    print(b^.peek(), b^.r.id)
    var c = Holder(Res(3), 9)
    print(c^.take())
    var d = Holder(Res(4), 10)
    var e = Holder(Res(5), 11)
    print(d^.take_plus(e^.take()), "end")
