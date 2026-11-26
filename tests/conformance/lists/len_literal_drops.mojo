@fieldwise_init
struct D(Copyable):
    var n: Int

    def __deinit__(deinit self):
        print("del", self.n)


def main():
    var d = D(5)
    print(len([D(1), D(2)]))
    print(len([[D(3)], [D(4)]]), "mid")
    print(len([d^, D(6)]))
    print("end")
