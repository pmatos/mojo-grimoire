@fieldwise_init
struct T(Copyable):
    var n: Int

    def __iadd__(mut self, k: Int):
        self.n += k


def main():
    var t = T(1)
    t += True
