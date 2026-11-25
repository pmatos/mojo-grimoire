struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct A(Movable):
    var x: Int

    def m(self):
        var b: Bool = 5
        print(b)


struct S(Copyable):
    var r: Res


def main():
    print(1)
