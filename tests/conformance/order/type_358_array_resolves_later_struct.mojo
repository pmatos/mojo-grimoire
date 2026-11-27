struct A(Movable):
    var bs: Array[B, 1]

def f():
    var b: Bool = 5
    print(b)

struct B(Movable):
    var bs: Array[B, 1]

def main():
    print(1)
