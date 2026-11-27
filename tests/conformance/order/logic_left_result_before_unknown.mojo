@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(self) -> Int:
        return self.n


def main():
    var a = A(1)
    print(a and zz)
