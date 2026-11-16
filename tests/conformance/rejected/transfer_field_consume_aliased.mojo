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


def main():
    var a = Pair(Res(1), 7)
    print(a^.take_with(a))
