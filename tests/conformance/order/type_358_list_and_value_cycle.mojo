struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct A(Movable):
    var xs: List[B]
    var b: B

struct B(Movable):
    var as_: Array[A, 1]

def main():
    print(1)
