struct A(Movable):
    var bs: Array[List[B], 1]

    def __init__(out self):
        self.bs = [List[B]()]


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var a = A()
    a.bs[0].append(B(A()))
    print(len(a.bs[0]))
