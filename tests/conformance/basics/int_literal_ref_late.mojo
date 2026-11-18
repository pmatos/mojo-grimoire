struct Box(Movable):
    var v: Int

    def __init__(out self, ref a: Int, b: Int):
        self.v = a + b

    def add(self, ref a: Int, b: Int) -> Int:
        return self.v + a + b


def both(ref a: Int, b: Int) -> Int:
    return a + b


def bump(mut x: Int) -> Int:
    x += 10
    return 0


def main():
    var x = 1
    print(both([x], bump(x)))
    var box = Box([x], bump(x))
    print(box.v, box.add([x], bump(x)))
