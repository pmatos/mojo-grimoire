struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct A(Movable):
    var xs: List[B]
    var bs: Array[B, 1]

struct B(Movable):
    var as_: Array[A, 1]

def main():
    print(1)
