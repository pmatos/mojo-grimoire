@fieldwise_init
struct Tok(ImplicitlyCopyable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var ts: List[Tok] = [Tok(1), Tok(2)]
    var t = ts[0]^
    print(t.id)
