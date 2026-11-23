@fieldwise_init
struct U(Copyable):
    var n: Int

    def __bool__(self) -> Bool:
        print("ub")
        return False


@fieldwise_init
struct T(Copyable):
    var n: Int

    def __bool__(self) -> Bool:
        print("tb")
        return self.n != 0


def main():
    var t = T(1)
    var u = U(1)
    print(not t)
    print(u and t)
    print(t or u)
    print(t and u)
    print(t and True, False or t)
