struct G(Movable):
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def __getitem__(self, i: Int) -> Int:
        return self.x + i


def main():
    var s = G(1)
    print(s[-1])
