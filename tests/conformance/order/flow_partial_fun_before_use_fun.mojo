struct Res(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def __deinit__(deinit self):
        print("drop", self.id)


struct Two(Movable):
    var a: Res
    var b: Res

    def __init__(out self, var a: Res, var b: Res):
        self.a = a^
        self.b = b^


def f():
    var c = True
    if c:
        var t = Two(Res(1), Res(2))
        var y = t.a^
        print(y.id)


def g():
    var z: Int
    print(z)


def main():
    f()
    g()
