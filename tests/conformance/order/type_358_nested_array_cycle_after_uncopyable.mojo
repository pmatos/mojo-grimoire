struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

struct Pair(Movable):
    var halves: Array[Array[Pair, 2], 2]

def main():
    print(1)
