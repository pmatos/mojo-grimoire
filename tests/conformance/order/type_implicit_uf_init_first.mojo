struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct S(ImplicitlyCopyable):
    var r: Res

    def __init__(out self):
        self.r = Res(1)

    def m(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
