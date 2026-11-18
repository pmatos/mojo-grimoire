@fieldwise_init
struct S(Movable):
    var k: Int

    def get(self) -> Int:
        return self.k


def main():
    var s = S(7)
    ref t = s
    print(t^.get())
