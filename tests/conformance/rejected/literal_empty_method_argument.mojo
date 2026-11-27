@fieldwise_init
struct S(Movable):
    var k: Int

    def m(self, x: S):
        pass


def main():
    var s = S(7)
    s.m([])
