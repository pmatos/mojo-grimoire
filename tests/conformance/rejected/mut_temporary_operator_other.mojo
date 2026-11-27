@fieldwise_init
struct Res(ImplicitlyCopyable):
    var id: Int

    def __sub__(self, mut o: Res) -> Res:
        return Res(self.id - o.id)


def main():
    var a = Res(5)
    var b = a - Res(2)
    print(b.id)
