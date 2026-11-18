struct A(Movable):
    var bs: Array[B, 1]

    def __init__(out self, var b: B):
        self.bs = [b^]


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    print(1)
