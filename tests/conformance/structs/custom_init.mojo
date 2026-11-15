struct Counter(Movable):
    var count: Int
    var step: Int

    fn __init__(out self, step: Int):
        self.count = 0
        self.step = step


def main():
    var c = Counter(5)
    c.count += c.step
    print(c.count, c.step)
