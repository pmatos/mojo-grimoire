@fieldwise_init
struct P(Copyable, Movable):
    var x: Int

    def __add__(self, o: P) -> P:
        return P(self.x + o.x)


def main():
    var p = P(1)
    var a = [1, 2]
    print(a == [p + p, 2])
