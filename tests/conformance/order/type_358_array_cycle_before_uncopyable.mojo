struct Pair(Movable):
    var halves: Array[Pair, 2]

struct ZzRes(Movable):
    var id: Int

struct ZzBad(Copyable):
    var r: ZzRes

def main():
    print(1)
