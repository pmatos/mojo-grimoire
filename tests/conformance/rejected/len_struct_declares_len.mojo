struct T(Movable):
    var a: Int

    def __init__(out self):
        self.a = 2

    def __len__(self) -> Int:
        return self.a


def main():
    var t = T()
    print(len(t))
