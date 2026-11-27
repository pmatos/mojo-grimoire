@fieldwise_init
struct M(Movable):
    var n: Int

    def __bool__(mut self) -> Bool:
        return self.n != 0


def main():
    var r = [1] or M(1)
