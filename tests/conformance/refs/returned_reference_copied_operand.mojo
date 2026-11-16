@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def same(ref p: P) -> ref [p] P:
    return p


def take(var x: P) -> Int:
    return x.v


def main():
    var p = P(7)
    print(take(same(p)) + 1)
    print("end")
