@fieldwise_init
struct K(Movable):
    var n: Int

    def __deinit__(deinit self):
        print("del K", self.n)


@fieldwise_init
struct W(Movable):
    var b: Bool

    def __getitem__(self, var k: K) -> Bool:
        print("get", k.n)
        return self.b

    def __setitem__(mut self, var k: K, v: Bool):
        pass


    def __deinit__(deinit self):
        print("del W")


def main():
    var w = W(True)
    var k = K(5)
    print(w[k^] or False)
