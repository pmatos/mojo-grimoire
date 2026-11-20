@fieldwise_init
struct B(ImplicitlyCopyable):
    var v: Bool

    def __bool__(self) -> Bool:
        print("bool", self.v)
        return self.v

    def __deinit__(deinit self):
        print("del", self.v)


def get(ref b: B) -> ref [b] B:
    return b


def main():
    var p = B(True)
    var q = B(False)
    var r = p and get(q)
    print("r", r.v)
