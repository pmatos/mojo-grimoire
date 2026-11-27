struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct A(Movable):
    var bs: Array[Array[B, 1], 1]

    def __deinit__(deinit self):
        pass

struct B(Movable):
    var as_: Array[A, 1]

def main():
    print(1)
