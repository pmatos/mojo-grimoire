@fieldwise_init
struct A(ImplicitlyCopyable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0


def main():
    var t = True
    print(t or A(1))
