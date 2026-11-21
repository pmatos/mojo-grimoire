struct N:
    var v: Int

    def __init__(out self):
        self.v = 1


@fieldwise_init
struct A(Copyable):
    var x: N

    def m(self, Int: Int):
        var y: Int = 2
        print(y)


def main():
    print(1)
