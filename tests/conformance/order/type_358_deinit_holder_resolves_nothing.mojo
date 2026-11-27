struct S(Movable):
    var bs: Array[B, 1]

    def __deinit__(deinit self):
        pass

def f():
    var b: Bool = 5
    print(b)

struct B(Movable):
    var x: Nope

def main():
    print(1)
