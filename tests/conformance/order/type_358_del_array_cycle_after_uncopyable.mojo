@fieldwise_init
struct Res(Movable):
    var id: Int

@fieldwise_init
struct S(Copyable):
    var r: Res

struct A(Movable):
    var b: Array[A, 2]

    def __del__(deinit self):
        pass

def main():
    print(1)
