struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0

    def __deinit__(deinit self):
        print("del T", self.n)


def main():
    var a = T(1)
    var b = T(5)
    b = a and b
    print(b.n)
