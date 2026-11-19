struct A(Movable):
    var xs: Array[A, 1]

    def __init__(out self, var a: A):
        self.xs = [a^]

    def __deinit__(deinit self):
        print("drop A")


def main():
    print(1)
