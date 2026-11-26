struct S(Movable):
    var x: Int

    def __init__(out self):
        self.x = 1

    def __deinit__(deinit self):
        print(nope)

    def m(self):
        var b: Bool = 5
        print(b)


def main():
    print(1)
