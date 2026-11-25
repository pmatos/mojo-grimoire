def f():
    print(nope)


struct S(Movable):
    var x: Int


struct S(Movable):
    var y: Int


def main():
    f()
