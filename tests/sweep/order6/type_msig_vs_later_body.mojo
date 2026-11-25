struct S(Movable):
    var x: Int

    def m(self, y: Nope):
        print(1)

    def n(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
