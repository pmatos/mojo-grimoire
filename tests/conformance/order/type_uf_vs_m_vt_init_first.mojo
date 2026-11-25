struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct S(Copyable):
    var r: Res

    def __init__(out self):
        self.r = Res(1)

    def m(self):
        var Int = 3
        var k: Int = 4
        print(k)


def main():
    print(1)
