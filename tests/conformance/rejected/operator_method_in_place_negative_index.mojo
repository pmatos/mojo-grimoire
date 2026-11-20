@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(mut self, k: Int):
        self.n += k


def use(xs: List[T]):
    xs[-1] += 1


def main():
    use([T(1)])
