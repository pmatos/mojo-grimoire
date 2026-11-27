struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct Pair(Movable):
    var halves: Array[Pair, 2]

    def __deinit__(deinit self):
        pass

def main():
    print(1)
