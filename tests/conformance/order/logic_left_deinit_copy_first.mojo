@fieldwise_init
struct T(Movable):
    var n: Int

    def __bool__(deinit self) -> Bool:
        return self.n != 0


def main():
    var a = T(0)
    var b = T(2)
    var res = a^ or b
    print(res.n)
