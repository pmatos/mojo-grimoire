struct S(Movable):
    var s: S


struct A(Movable):
    var x: Int

    def m(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
