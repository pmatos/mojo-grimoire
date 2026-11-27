struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct C(Movable):
    var as_: Array[A, 1]

struct B(Movable):
    var cs: Array[C, 1]

struct A(Movable):
    var bs: Array[B, 1]

def main():
    print(1)
