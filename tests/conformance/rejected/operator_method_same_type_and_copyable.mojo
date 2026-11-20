@fieldwise_init
struct T(Copyable):
    var n: Int

    def __bool__(self) -> Bool:
        return self.n != 0


def main():
    var t = T(1)
    var u = T(0)
    var x = t and u
    print(x.n)
