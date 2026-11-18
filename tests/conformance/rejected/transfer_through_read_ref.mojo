@fieldwise_init
struct S(Movable):
    var k: Int

    def take(var self) -> Int:
        return self.k

    def get(self) -> Int:
        return self.k


def f(s: S):
    ref t = s
    var u = t^
    print(u.k)


def main():
    var s = S(7)
    f(s)
