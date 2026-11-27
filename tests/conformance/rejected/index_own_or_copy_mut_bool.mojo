@fieldwise_init
struct T(Movable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0


def main():
    var t0 = T(2)
    var t2 = T(1)
    var lT: List[T] = [T(0)]
    var r = lT[((t2 or t0) or t2)]
    print(r.n)
