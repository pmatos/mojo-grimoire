struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct A(Movable):
    var bs: Array[B, 2]

struct B(Movable):
    var as_: Array[A, 2]

def main():
    print(1)
