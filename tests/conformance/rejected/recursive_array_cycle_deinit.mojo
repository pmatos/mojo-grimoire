struct A(Movable):
    var bs: Array[B, 1]

    def __init__(out self, var b: B):
        self.bs = [b^]

    def __deinit__(deinit self):
        print("drop A")


struct B(Movable):
    var as_: Array[A, 1]

    def __init__(out self, var a: A):
        self.as_ = [a^]

    def __deinit__(deinit self):
        print("drop B")


def main():
    print(1)
