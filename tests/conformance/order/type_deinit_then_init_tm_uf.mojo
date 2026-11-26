struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct S(Copyable):
    var r: Res

    def __deinit__(deinit self):
        print(nope)

    def __init__(out self):
        self.r = Res(1)


def main():
    print(1)
