struct T:
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def set(mut self, a: Int, b: Int):
        self.x = a + b


def main():
    var t = T(1)
    t.set(2)
    print(t.x)
