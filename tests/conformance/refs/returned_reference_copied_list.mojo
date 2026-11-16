@fieldwise_init
struct P(ImplicitlyCopyable):
    var v: Int

    def __deinit__(deinit self):
        print("drop", self.v)


def same(ref p: P) -> ref [p] P:
    return p


def main():
    var p = P(7)
    var ps: List[P] = [same(p)]
    print(len(ps))
    print("end")
