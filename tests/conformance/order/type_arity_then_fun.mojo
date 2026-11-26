struct S(Movable):
    var x: Int

    def __add__(self) -> Int:
        return 1


def f():
    print(nope)


def main():
    f()
