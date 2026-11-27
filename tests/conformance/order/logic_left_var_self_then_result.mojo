@fieldwise_init
struct M(Movable):
    var n: Int

    def __bool__(var self) -> Int:
        return self.n


def main():
    var m = M(1)
    print(m or True)
