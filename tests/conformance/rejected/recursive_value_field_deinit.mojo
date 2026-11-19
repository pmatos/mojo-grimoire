struct A(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^

    def __deinit__(deinit self):
        print("drop A")


def main():
    print(1)
