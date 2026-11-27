struct S(Movable):
    var bs: Array[B, 1]

def f():
    var b: Bool = 5
    print(b)

struct B(Movable):
    var m: Int

    def m(self):
        pass

def main():
    print(1)
