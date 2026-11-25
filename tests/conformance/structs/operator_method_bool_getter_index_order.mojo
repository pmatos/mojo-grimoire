@fieldwise_init
struct K(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("del K", self.n)


@fieldwise_init
struct W(Movable):
    var b: Bool

    def __getitem__(self, i: Int) -> Bool:
        print("get", i)
        return self.b

    def __setitem__(mut self, i: Int, v: Bool):
        pass


    def __deinit__(deinit self):
        print("del W")


def bump(mut w: W) -> Bool:
    w.b = not w.b
    print("bump")
    return True


def main():
    var k = K(1)
    var w = W(True)
    print(w[k.n] and bump(w))
