@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def id(ref x: Int) -> ref [x] Int:
    return x


def same(ref p: P) -> ref [p] P:
    return p


def show(ref a: Int) -> Int:
    return a


def show_p(ref p: P) -> Int:
    return p.v


def main():
    print(show(id(5)))
    print(show_p(same(P(1))))
    print("end")
