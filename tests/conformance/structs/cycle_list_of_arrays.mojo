struct A(Movable):
    var bs: List[Array[B, 1]]

    def __init__(out self):
        self.bs = List[Array[B, 1]]()


struct B(Movable):
    var a: A

    def __init__(out self, var a: A):
        self.a = a^


def main():
    var a = A()
    var arr: Array[B, 1] = [B(A())]
    a.bs.append(arr^)
    print(len(a.bs))
