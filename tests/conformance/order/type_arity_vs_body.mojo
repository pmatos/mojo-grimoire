struct S(Movable):
    var x: Int

    def m(self):
        print(nope)

    def __add__(self) -> Int:
        return 1


def main():
    print(1)
