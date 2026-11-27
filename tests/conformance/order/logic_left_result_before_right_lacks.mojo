@fieldwise_init
struct A(Movable):
    var n: Int

    def __bool__(self) -> Int:
        return self.n


@fieldwise_init
struct B(Copyable):
    var n: Int


def idB(var x: B) -> B:
    return x^


def main():
    var b = B(1)
    var r = A(3) and idB(b)
