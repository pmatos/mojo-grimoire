struct Box(Movable):
    var value: Int

    def __init__(out self, mut seed: Int):
        self.value = seed
        seed = 0


def main():
    var b = Box(7)
    print(b.value)
