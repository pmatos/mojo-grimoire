struct A(Movable):
    var x: Int

    def m(self):
        var b: Bool = 5
        print(b)


struct S(Movable):
    var s: S


def main():
    print(1)
