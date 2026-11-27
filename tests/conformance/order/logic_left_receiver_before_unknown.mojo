@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0

def f(a: A, b: A):
    var r = a or A(zz)


def main():
    print(1)
