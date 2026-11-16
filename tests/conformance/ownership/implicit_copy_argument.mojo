@fieldwise_init
struct Tok(ImplicitlyCopyable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def take(var t: Tok) -> Int:
    print("take", t.id)
    return t.id


def main():
    var t = Tok(1)
    print(take(t))
