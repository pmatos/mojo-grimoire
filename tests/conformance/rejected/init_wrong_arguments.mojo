struct Celsius(Movable):
    var degrees: Int

    def __init__(out self, degrees: Int):
        self.degrees = degrees


def main():
    var t = Celsius(20, 5)
    print(t.degrees)
