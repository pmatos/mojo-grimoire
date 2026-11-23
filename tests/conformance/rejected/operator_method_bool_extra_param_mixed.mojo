struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self, k: Int) -> Bool:
        return self.n != k

    def __deinit__(deinit self):
        print("del T", self.n)


def main():
    var a = T(0)
    var b = T(2)
    var y = a or True
    print(y)
