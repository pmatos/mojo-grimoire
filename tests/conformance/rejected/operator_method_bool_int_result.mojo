struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Int:
        return self.n


def main():
    var a = T(0)
    var b = T(2)
    var x = a or b
    print(x.n)
