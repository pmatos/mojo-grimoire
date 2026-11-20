@fieldwise_init
struct T(ImplicitlyCopyable):
    var x: Int

    def __add__(self, o: Self) -> Self:
        return Self(self.x + o.x)

    def __neg__(self) -> Self:
        return Self(-self.x)

    def twice(self) -> Self:
        var r = Self(self.x * 2)
        return r^


def main():
    var a = T(1)
    var b = T(2)
    var c = a + b
    var d = -c
    var e = d.twice()
    print(c.x, d.x, e.x)
