@fieldwise_init
struct S(Movable):
    var k: Int

    def take(var self) -> Int:
        return self.k

    def get(self) -> Int:
        return self.k


def main():
    var s = S(7)
    ref t = s
    t = S(3)
    var u = t^
    print(u.k)
