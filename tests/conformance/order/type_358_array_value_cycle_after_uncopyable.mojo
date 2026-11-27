struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct A(Movable):
    var bs: Array[B, 1]

struct B(Movable):
    var a: A

def main():
    print(1)
