@fieldwise_init
struct Res(ImplicitlyCopyable):
    var id: Int

    def __add__(mut self, o: Res) -> Res:
        return Res(self.id + o.id)


def main():
    var a = Res(1)
    var b = Res(2) + a
    print(b.id)
