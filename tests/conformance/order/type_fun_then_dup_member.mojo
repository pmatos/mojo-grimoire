def f():
    print(nope)


struct S(Movable):
    var m: Int

    def m(self):
        print(1)


def main():
    f()
