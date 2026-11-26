struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id


struct A(Copyable):
    var r: Res
    var a: A


def main():
    print(1)
