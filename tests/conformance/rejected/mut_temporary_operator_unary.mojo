@fieldwise_init
struct Res(ImplicitlyCopyable):
    var id: Int

    def __neg__(mut self) -> Res:
        return Res(-self.id)


def main():
    var b = -Res(2)
    print(b.id)
