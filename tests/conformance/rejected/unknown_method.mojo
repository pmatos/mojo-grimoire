@fieldwise_init
struct Counter(Movable):
    var n: Int

    def bump(mut self):
        self.n += 1


def main():
    var c = Counter(0)
    c.bump()
    c.reset()
    print(c.n)
