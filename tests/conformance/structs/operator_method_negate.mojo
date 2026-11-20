@fieldwise_init
struct T(Copyable):
    var n: Int

    def __neg__(self) -> Self:
        print("neg", self.n)
        return T(-self.n)

    def __deinit__(deinit self):
        print("del T", self.n)


def main():
    var t = T(5)
    var u = -(-t)
    print("got", u.n)
