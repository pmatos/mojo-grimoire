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
struct Outer(Movable):
    var p: Pair
    var n: Int


def show(x: Int):
    print("show", x)


def own(var x: Int):
    print("own", x)


def main():
    var a = Pair(Res(1), 7)
    var y = a^.k
    print("after", y)
    var b = Pair(Res(2), 8)
    show(b^.k)
    own(b^ .k)
    print(b^.r.id, b.k)
    var o = Outer(Pair(Res(3), 9), 4)
    print(o^.p.k, o.p^.r.id, o.n)
