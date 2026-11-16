@fieldwise_init
struct Tok(ImplicitlyCopyable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def take(var t: Tok) -> Int:
    return t.id


def main():
    var ts: List[Tok] = [Tok(1), Tok(2)]
    print(take(ts[0]^))
