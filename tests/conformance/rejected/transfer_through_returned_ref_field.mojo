@fieldwise_init
struct S(Movable):
    var k: Int

    def take(var self) -> Int:
        return self.k

    def get(self) -> Int:
        return self.k


def same(ref x: S) -> ref [x] S:
    return x


def main():
    var s = S(7)
    ref t = same(s)
    print(t^.k)
