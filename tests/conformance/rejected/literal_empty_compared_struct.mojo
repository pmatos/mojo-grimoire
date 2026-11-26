@fieldwise_init
struct S(Movable):
    var k: Int

    def __eq__(self, x: S) -> Bool:
        return True


def main():
    var s = S(7)
    print(s == [])
