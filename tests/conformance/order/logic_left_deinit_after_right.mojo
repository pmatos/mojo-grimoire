@fieldwise_init
struct T(ImplicitlyCopyable):
    var n: Int

    def __bool__(deinit self) -> Bool:
        return self.n != 0


def main():
    var a = T(0)
    var r = a or T(zz)
