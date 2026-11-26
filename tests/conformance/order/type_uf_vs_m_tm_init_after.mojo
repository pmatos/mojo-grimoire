struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct S(Copyable):
    var r: Res

    def m(self):
        var b: Bool = 5
        print(b)

    def __init__(out self):
        self.r = Res(1)


def main():
    print(1)
