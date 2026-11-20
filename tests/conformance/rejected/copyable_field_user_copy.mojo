@fieldwise_init
struct Res(Movable):
    var id: Int


@fieldwise_init
struct S(Copyable):
    var r: Res

    def copy(self) -> Self:
        return S(Res(self.r.id))


def main():
    var s = S(Res(4))
    var t = s.copy()
    print(t.r.id)
