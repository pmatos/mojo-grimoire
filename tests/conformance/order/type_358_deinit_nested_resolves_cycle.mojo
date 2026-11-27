struct S(Movable):
    var bs: Array[Array[B, 1], 1]

    def __deinit__(deinit self):
        pass

def f():
    var b: Bool = 5
    print(b)

struct B(Movable):
    var as_: Array[B, 1]

def main():
    print(1)
