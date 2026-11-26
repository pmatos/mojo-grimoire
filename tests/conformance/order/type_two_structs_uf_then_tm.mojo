struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct S(Copyable):
    var r: Res


struct A(Movable):
    var x: Int

    def m(self):
        print(nope)


def main():
    print(1)
