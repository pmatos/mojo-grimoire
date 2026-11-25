struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct A(Copyable):
    var a: A
    var r: Res

    def m(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
