struct A(Movable):
    var b: B

    def __init__(out self, var b: B):
        self.b = b^


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    print(1)
